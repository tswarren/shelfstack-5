# frozen_string_literal: true

module Inventory
  # Exact historical reversal of one inventory ledger entry.
  #
  # Applies the inverse of the original quantity, inventory-value, unavailable,
  # and deficit-pool effects. For OD-014 Case 1 (still-open deficit), uses the
  # exact provisional contribution of the original entry rather than proportional
  # current-pool release (Phase 6 / ADR-0008 / ADR-0013).
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
        inventory_value_delta =
          if original.inventory_value_delta_cents.nil?
            nil
          else
            -original.inventory_value_delta_cents
          end

        resulting_on_hand = balance.on_hand + quantity_delta
        resulting_unavailable = balance.unavailable + unavailable_delta
        raise Error, "unavailable cannot become negative" if resulting_unavailable.negative?
        assert_safe_deficit_reverse!(original, balance, resulting_on_hand)

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

        deficit = exact_deficit_inverse(original, balance, resulting_on_hand)
        prior_pool = balance.open_provisional_deficit_cost_cents
        prior_deficit_quality = balance.deficit_cost_quality

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
          prior_open_provisional_deficit_cost_cents: deficit.changed ? prior_pool : nil,
          resulting_open_provisional_deficit_cost_cents: deficit.changed ? deficit.resulting_open_provisional_deficit_cost_cents : nil,
          prior_deficit_cost_quality: deficit.changed ? prior_deficit_quality : nil,
          resulting_deficit_cost_quality: deficit.changed ? deficit.resulting_deficit_cost_quality : nil,
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

    DeficitInverse = Data.define(
      :changed,
      :resulting_open_provisional_deficit_cost_cents,
      :resulting_deficit_cost_quality,
      :provisional_cost_released_cents,
      :provisional_deficit_cost_quality_snapshot
    )
    private_constant :DeficitInverse

    NO_DEFICIT = DeficitInverse.new(
      changed: false,
      resulting_open_provisional_deficit_cost_cents: nil,
      resulting_deficit_cost_quality: nil,
      provisional_cost_released_cents: nil,
      provisional_deficit_cost_quality_snapshot: nil
    )
    private_constant :NO_DEFICIT

    # Interim OD-014 guard: snapshot restore is only safe when no later deficit
    # quantity change exists after a deficit-affecting original (increase or
    # reduction), and when a non-deficit original would not settle today's open
    # deficit.
    def assert_safe_deficit_reverse!(original, balance, resulting_on_hand)
      prior_on_hand = original.resulting_on_hand - original.quantity_delta
      prior_deficit = [ -prior_on_hand, 0 ].max
      original_deficit = [ -original.resulting_on_hand, 0 ].max
      changed_deficit = original_deficit != prior_deficit

      later = InventoryLedgerEntry
        .where(store_id: original.store_id, product_variant_id: original.product_variant_id)
        .where("posted_at > ? OR (posted_at = ? AND id > ?)", original.posted_at, original.posted_at, original.id)

      if changed_deficit
        later.find_each do |entry|
          prev = entry.resulting_on_hand - entry.quantity_delta
          prev_def = [ -prev, 0 ].max
          next_def = [ -entry.resulting_on_hand, 0 ].max
          if next_def != prev_def
            raise ConflictError,
                  "cannot reverse deficit-affecting entry #{original.id} after later deficit activity (OD-014 interim)"
          end
        end
        return
      end

      current_deficit = [ -balance.on_hand, 0 ].max
      resulting_deficit = [ -resulting_on_hand, 0 ].max
      if resulting_deficit < current_deficit
        raise ConflictError,
              "cannot reverse entry #{original.id}: would settle current deficit without pool correction (OD-014 interim)"
      end
    end

    # Exact inverse of the original entry's deficit-pool effect (Case 1).
    # Prefers persisted prior/resulting pool snapshots on the original row.
    def exact_deficit_inverse(original, balance, resulting_on_hand)
      unless original.prior_deficit_cost_quality.present? ||
             !original.prior_open_provisional_deficit_cost_cents.nil? ||
             !original.resulting_open_provisional_deficit_cost_cents.nil?
        return NO_DEFICIT unless deficit_quantity_changed?(original)

        return legacy_exact_deficit_inverse(original, balance, resulting_on_hand)
      end

      resulting_deficit_qty = [ -resulting_on_hand, 0 ].max
      restored_pool = original.prior_open_provisional_deficit_cost_cents
      restored_quality = original.prior_deficit_cost_quality.presence || "unknown"

      if resulting_deficit_qty.zero?
        restored_pool = 0
        restored_quality = "unknown"
      end

      released = if original.resulting_open_provisional_deficit_cost_cents.nil? && restored_pool.nil?
        nil
      elsif original.resulting_open_provisional_deficit_cost_cents.nil?
        nil
      elsif restored_pool.nil?
        original.resulting_open_provisional_deficit_cost_cents
      else
        original.resulting_open_provisional_deficit_cost_cents - restored_pool
      end

      DeficitInverse.new(
        changed: true,
        resulting_open_provisional_deficit_cost_cents: restored_pool,
        resulting_deficit_cost_quality: restored_quality,
        provisional_cost_released_cents: released&.positive? ? released : nil,
        provisional_deficit_cost_quality_snapshot: original.resulting_deficit_cost_quality
      )
    end

    def deficit_quantity_changed?(original)
      prior_on_hand = original.resulting_on_hand - original.quantity_delta
      prior_deficit_qty = [ -prior_on_hand, 0 ].max
      original_deficit_qty = [ -original.resulting_on_hand, 0 ].max
      prior_deficit_qty != original_deficit_qty
    end

    # Fallback for ledger rows posted before deficit snapshots existed.
    def legacy_exact_deficit_inverse(original, balance, resulting_on_hand)
      prior_on_hand = original.resulting_on_hand - original.quantity_delta
      prior_deficit_qty = [ -prior_on_hand, 0 ].max
      original_deficit_qty = [ -original.resulting_on_hand, 0 ].max
      created_qty = original_deficit_qty - prior_deficit_qty

      if created_qty.positive?
        exact_added = if original.unit_cost_cents.present? &&
                         CalculateQuantityCost::KNOWN_QUALITIES.include?(original.cost_quality.to_s)
          Rounding.multiply_round_half_up(original.unit_cost_cents, created_qty)
        end
        resulting_deficit_qty = [ -resulting_on_hand, 0 ].max
        if resulting_deficit_qty.zero?
          return DeficitInverse.new(
            changed: true,
            resulting_open_provisional_deficit_cost_cents: 0,
            resulting_deficit_cost_quality: "unknown",
            provisional_cost_released_cents: balance.open_provisional_deficit_cost_cents,
            provisional_deficit_cost_quality_snapshot: balance.deficit_cost_quality
          )
        end
        if exact_added && balance.open_provisional_deficit_cost_cents
          pool = balance.open_provisional_deficit_cost_cents - exact_added
          raise Error, "exact deficit reverse would make provisional pool negative" if pool.negative?

          return DeficitInverse.new(
            changed: true,
            resulting_open_provisional_deficit_cost_cents: pool,
            resulting_deficit_cost_quality: balance.deficit_cost_quality,
            provisional_cost_released_cents: exact_added,
            provisional_deficit_cost_quality_snapshot: balance.deficit_cost_quality
          )
        end
      elsif created_qty.negative? && original.provisional_cost_released_cents
        pool = (balance.open_provisional_deficit_cost_cents || 0) + original.provisional_cost_released_cents
        return DeficitInverse.new(
          changed: true,
          resulting_open_provisional_deficit_cost_cents: pool,
          resulting_deficit_cost_quality: original.provisional_deficit_cost_quality_snapshot || balance.deficit_cost_quality,
          provisional_cost_released_cents: nil,
          provisional_deficit_cost_quality_snapshot: nil
        )
      end

      NO_DEFICIT
    end

    def resulting_valuation(balance, resulting_on_hand, inventory_value_delta)
      if resulting_on_hand <= 0
        return [ 0, nil, "unknown" ]
      end

      # Unknown historical contribution must not invent confirmed-zero value.
      if inventory_value_delta.nil?
        return [ nil, nil, "unknown" ]
      end

      prior_value = balance.inventory_value_cents
      if prior_value.nil? && balance.on_hand <= 0
        resulting_value = inventory_value_delta.positive? ? inventory_value_delta : nil
      elsif prior_value.nil?
        return [ nil, nil, "unknown" ]
      else
        resulting_value = prior_value + inventory_value_delta
      end

      if resulting_value.nil? || resulting_value.negative?
        return [ nil, nil, "unknown" ]
      end

      resulting_mwa = Rounding.round_half_up(resulting_value, resulting_on_hand)
      movement_quality = @original.cost_quality.to_s
      prior_quality = balance.on_hand.positive? ? balance.cost_quality.to_s : nil
      resulting_quality = if prior_quality.blank? || prior_quality == "unknown" || balance.on_hand <= 0
        CalculateQuantityCost::KNOWN_QUALITIES.include?(movement_quality) ? movement_quality : "unknown"
      else
        aggregate_cost_quality(prior_quality, movement_quality)
      end

      [ resulting_value, resulting_mwa, resulting_quality ]
    end

    def aggregate_cost_quality(existing, incoming)
      return "unknown" if existing == "unknown" || incoming == "unknown"
      return "mixed" if existing == "mixed" || incoming == "mixed"
      return existing if existing == incoming

      "mixed"
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
      expected_value_delta =
        if @original.inventory_value_delta_cents.nil?
          nil
        else
          -@original.inventory_value_delta_cents
        end

      existing.reversal_of_entry_id == @original.id &&
        existing.quantity_delta == -@original.quantity_delta &&
        existing.unavailable_delta.to_i == -@original.unavailable_delta.to_i &&
        existing.inventory_value_delta_cents == expected_value_delta &&
        existing.source_type == @source.class.name &&
        existing.source_id == @source.id
    end
  end
end
