# frozen_string_literal: true

module Inventory
  # Exact historical reversal of one inventory ledger entry.
  #
  # Applies the inverse of the original quantity, inventory-value, unavailable,
  # and eligible deficit-pool effects. Derives the resulting current balance and
  # carrying average deterministically. Never reprices or recosts the original
  # movement (Phase 6 / ADR-0008 / ADR-0013).
  class ReverseLedgerEntry < ApplicationService
    Error = Class.new(StandardError)
    ConflictError = Class.new(Error)
    IdempotencyConflictError = Class.new(Error)

    Result = Data.define(:ledger_entry, :stock_balance, :replayed)

    def initialize(
      reversal_of_entry:,
      source:,
      posting_key:,
      posted_by_user:,
      posted_at: nil,
      reason_code: nil,
      reason_note: nil
    )
      @original = reversal_of_entry
      @source = source
      @posting_key = posting_key.to_s
      @posted_by_user = posted_by_user
      @posted_at = posted_at || Time.current
      @reason_code = reason_code
      @reason_note = reason_note
    end

    def call
      raise Error, "posting_key is required" if @posting_key.blank?
      raise Error, "original entry is required" if @original.blank?

      existing = InventoryLedgerEntry.find_by(posting_key: @posting_key)
      return replay_or_conflict!(existing) if existing

      ActiveRecord::Base.transaction do
        original = InventoryLedgerEntry.lock.find(@original.id)
        if InventoryLedgerEntry.exists?(reversal_of_entry_id: original.id)
          raise ConflictError, "ledger entry #{original.id} is already reversed"
        end

        balance = FindOrCreateStockBalance.call(
          store: original.store,
          product_variant: original.product_variant
        )

        quantity_delta = -original.quantity_delta
        unavailable_delta = -original.unavailable_delta.to_i
        inventory_value_delta = -(original.inventory_value_delta_cents || 0)

        resulting_on_hand = balance.on_hand + quantity_delta
        resulting_unavailable = balance.unavailable + unavailable_delta
        raise Error, "unavailable cannot become negative" if resulting_unavailable.negative?

        resulting_value, resulting_mwa, resulting_quality = resulting_valuation(
          balance, resulting_on_hand, inventory_value_delta
        )

        calc = ReversalCalc.new(
          resulting_on_hand: resulting_on_hand,
          inventory_value_delta_cents: inventory_value_delta,
          resulting_inventory_value_cents: resulting_value,
          resulting_moving_average_cost_cents: resulting_mwa,
          resulting_cost_quality: resulting_quality,
          unit_cost_cents: original.unit_cost_cents,
          cost_method: original.cost_method,
          cost_quality: original.cost_quality,
          movement_cost_cents: original.movement_cost_cents
        )

        deficit = PostLedgerEntry.deficit_effect_for(
          balance: balance,
          resulting_on_hand: resulting_on_hand,
          movement_type: original.movement_type,
          unit_cost_cents: original.unit_cost_cents,
          cost_quality: original.cost_quality
        )

        entry = InventoryLedgerEntry.create!(
          store: original.store,
          product_variant: original.product_variant,
          movement_type: original.movement_type,
          quantity_delta: quantity_delta,
          unavailable_delta: unavailable_delta,
          resulting_unavailable: resulting_unavailable,
          availability_reason: original.availability_reason,
          inventory_value_delta_cents: inventory_value_delta,
          movement_cost_cents: original.movement_cost_cents,
          unit_cost_cents: original.unit_cost_cents,
          cost_method: original.cost_method,
          cost_quality: original.cost_quality,
          resulting_on_hand: resulting_on_hand,
          resulting_inventory_value_cents: resulting_value,
          resulting_moving_average_cost_cents: resulting_mwa,
          resulting_cost_quality: resulting_quality,
          reason_code: @reason_code || original.reason_code,
          reason_note: @reason_note || original.reason_note,
          source: @source,
          reversal_of_entry: original,
          provisional_cost_released_cents: deficit.provisional_cost_released_cents,
          provisional_deficit_cost_quality_snapshot: deficit.provisional_deficit_cost_quality_snapshot,
          settlement_variance_cents: nil,
          settlement_variance_kind: nil,
          posting_key: @posting_key,
          posted_by_user: @posted_by_user,
          posted_at: @posted_at
        )

        apply_balance!(balance, calc, deficit, resulting_unavailable)
        Result.new(ledger_entry: entry, stock_balance: balance, replayed: false)
      end
    rescue ActiveRecord::RecordNotUnique
      existing = InventoryLedgerEntry.find_by(posting_key: @posting_key)
      if existing
        replay_or_conflict!(existing)
      else
        raise ConflictError, "ledger entry is already reversed"
      end
    end

    private

    ReversalCalc = Struct.new(
      :resulting_on_hand,
      :inventory_value_delta_cents,
      :resulting_inventory_value_cents,
      :resulting_moving_average_cost_cents,
      :resulting_cost_quality,
      :unit_cost_cents,
      :cost_method,
      :cost_quality,
      :movement_cost_cents,
      keyword_init: true
    )
    private_constant :ReversalCalc

    def resulting_valuation(balance, resulting_on_hand, inventory_value_delta)
      if resulting_on_hand <= 0
        return [ 0, nil, "unknown" ]
      end

      prior_value = balance.inventory_value_cents
      if prior_value.nil? && balance.on_hand <= 0
        # Restoring into positive from zero/negative with an explicit historical
        # value delta — treat the delta as the new carrying value when positive.
        resulting_value = inventory_value_delta.positive? ? inventory_value_delta : nil
      else
        resulting_value = (prior_value || 0) + inventory_value_delta
      end

      if resulting_value.nil? || resulting_value.negative?
        return [ nil, nil, "unknown" ]
      end

      resulting_mwa = Rounding.round_half_up(resulting_value, resulting_on_hand)
      [ resulting_value, resulting_mwa, balance.cost_quality.presence || "unknown" ]
    end

    def apply_balance!(balance, calc, deficit, resulting_unavailable)
      attrs = {
        on_hand: calc.resulting_on_hand,
        unavailable: resulting_unavailable,
        inventory_value_cents: calc.resulting_inventory_value_cents || (calc.resulting_on_hand.positive? ? nil : 0),
        moving_average_cost_cents: calc.resulting_moving_average_cost_cents,
        cost_quality: calc.resulting_cost_quality
      }

      if calc.resulting_on_hand.positive? &&
         calc.resulting_moving_average_cost_cents &&
         CalculateQuantityCost::KNOWN_QUALITIES.include?(calc.resulting_cost_quality)
        attrs[:last_known_unit_cost_cents] = calc.resulting_moving_average_cost_cents
        attrs[:last_known_cost_quality] = calc.resulting_cost_quality
      end

      if deficit.changed
        attrs[:open_provisional_deficit_cost_cents] = deficit.resulting_open_provisional_deficit_cost_cents
        attrs[:deficit_cost_quality] = deficit.resulting_deficit_cost_quality
      end

      balance.update!(attrs)
    end

    def replay_or_conflict!(existing)
      unless compatible_with?(existing)
        raise IdempotencyConflictError, "posting_key #{@posting_key} already used with different intent"
      end

      balance = StockBalance.find_by!(
        store_id: existing.store_id,
        product_variant_id: existing.product_variant_id
      )
      Result.new(ledger_entry: existing, stock_balance: balance, replayed: true)
    end

    def compatible_with?(existing)
      existing.reversal_of_entry_id == @original.id &&
        existing.quantity_delta == -@original.quantity_delta &&
        existing.unavailable_delta.to_i == -@original.unavailable_delta.to_i &&
        existing.inventory_value_delta_cents.to_i == -(@original.inventory_value_delta_cents || 0) &&
        existing.source_type == @source.class.name &&
        existing.source_id == @source.id
    end
  end
end
