# frozen_string_literal: true

module Inventory
  # Exclusive owner of Stock Balance On Hand and valuation-state changes.
  class PostLedgerEntry < ApplicationService
    Error = Class.new(StandardError)
    ConflictError = Class.new(Error)
    IdempotencyConflictError = Class.new(Error)

    Result = Data.define(:ledger_entry, :stock_balance, :replayed)

    def initialize(
      store:,
      product_variant:,
      movement_type:,
      quantity_delta:,
      source:,
      posting_key:,
      posted_by_user:,
      movement_kind: nil,
      incoming_unit_cost_cents: nil,
      incoming_cost_method: nil,
      incoming_cost_quality: nil,
      corrected_inventory_value_cents: nil,
      reason_code: nil,
      reason_note: nil,
      estimate_department: nil,
      estimate_regular_price_cents: nil,
      estimate_margin_bps: nil,
      estimate_unit_cost_cents: nil,
      posted_at: nil
    )
      @store = store
      @product_variant = product_variant
      @movement_type = movement_type.to_s
      @quantity_delta = quantity_delta.to_i
      @source = source
      @posting_key = posting_key.to_s
      @posted_by_user = posted_by_user
      @movement_kind = (movement_kind || infer_movement_kind).to_sym
      @incoming_unit_cost_cents = incoming_unit_cost_cents
      @incoming_cost_method = incoming_cost_method
      @incoming_cost_quality = incoming_cost_quality
      @corrected_inventory_value_cents = corrected_inventory_value_cents
      @reason_code = reason_code
      @reason_note = reason_note
      @estimate_department = estimate_department
      @estimate_regular_price_cents = estimate_regular_price_cents
      @estimate_margin_bps = estimate_margin_bps
      @estimate_unit_cost_cents = estimate_unit_cost_cents
      @posted_at = posted_at || Time.current
    end

    def call
      validate_preconditions!

      existing = InventoryLedgerEntry.find_by(posting_key: @posting_key)
      return replay_or_conflict!(existing) if existing

      ActiveRecord::Base.transaction do
        balance = FindOrCreateStockBalance.call(store: @store, product_variant: @product_variant)

        calc = CalculateQuantityCost.call(
          prior_on_hand: balance.on_hand,
          prior_inventory_value_cents: balance.inventory_value_cents,
          prior_moving_average_cost_cents: balance.moving_average_cost_cents,
          prior_cost_quality: balance.cost_quality,
          quantity_delta: @quantity_delta,
          movement_kind: @movement_kind,
          incoming_unit_cost_cents: @incoming_unit_cost_cents,
          incoming_cost_method: @incoming_cost_method,
          incoming_cost_quality: @incoming_cost_quality,
          corrected_inventory_value_cents: @corrected_inventory_value_cents,
          prior_last_known_unit_cost_cents: balance.last_known_unit_cost_cents,
          prior_last_known_cost_quality: balance.last_known_cost_quality
        )

        entry = InventoryLedgerEntry.create!(
          store: @store,
          product_variant: @product_variant,
          movement_type: @movement_type,
          quantity_delta: @quantity_delta,
          inventory_value_delta_cents: calc.inventory_value_delta_cents,
          movement_cost_cents: calc.movement_cost_cents,
          unit_cost_cents: calc.unit_cost_cents,
          cost_method: calc.cost_method,
          cost_quality: calc.cost_quality,
          resulting_on_hand: calc.resulting_on_hand,
          resulting_inventory_value_cents: calc.resulting_inventory_value_cents,
          resulting_moving_average_cost_cents: calc.resulting_moving_average_cost_cents,
          resulting_cost_quality: calc.resulting_cost_quality,
          reason_code: @reason_code,
          reason_note: @reason_note,
          source: @source,
          estimate_department: @estimate_department,
          estimate_regular_price_cents: @estimate_regular_price_cents,
          estimate_margin_bps: @estimate_margin_bps,
          estimate_unit_cost_cents: @estimate_unit_cost_cents,
          posting_key: @posting_key,
          posted_by_user: @posted_by_user,
          posted_at: @posted_at
        )

        apply_balance!(balance, calc)
        Result.new(ledger_entry: entry, stock_balance: balance, replayed: false)
      end
    rescue ArgumentError => e
      raise Error, e.message
    rescue ActiveRecord::RecordNotUnique
      existing = InventoryLedgerEntry.find_by!(posting_key: @posting_key)
      replay_or_conflict!(existing)
    end

    private

    def validate_preconditions!
      raise Error, "posting_key is required" if @posting_key.blank?
      raise Error, "store and variant must share organization" unless same_organization?
      unless @product_variant.inventory_tracking_mode == "quantity"
        raise Error, "product variant must be quantity-tracked"
      end
    end

    def same_organization?
      @store.organization_id == @product_variant.organization.id
    end

    def infer_movement_kind
      case @movement_type
      when "opening_inventory" then :opening_inventory
      when "quantity_adjustment" then :quantity_only
      when "cost_correction" then :cost_correction
      when "sale" then :sale
      when "customer_return" then :customer_return
      else
        raise Error, "unsupported movement_type: #{@movement_type}"
      end
    end

    def apply_balance!(balance, calc)
      attrs = {
        on_hand: calc.resulting_on_hand,
        inventory_value_cents: calc.resulting_inventory_value_cents || (calc.resulting_on_hand.positive? ? nil : 0),
        moving_average_cost_cents: calc.resulting_moving_average_cost_cents,
        cost_quality: calc.resulting_cost_quality
      }

      # Keep last_known synchronized with every known positive carrying rate.
      # When On Hand reaches zero/negative, leave last_known unchanged (pre-zero rate).
      if calc.resulting_on_hand.positive? &&
         calc.resulting_moving_average_cost_cents &&
         CalculateQuantityCost::KNOWN_QUALITIES.include?(calc.resulting_cost_quality)
        attrs[:last_known_unit_cost_cents] = calc.resulting_moving_average_cost_cents
        attrs[:last_known_cost_quality] = calc.resulting_cost_quality
      end

      balance.update!(attrs)
    end


    def replay_or_conflict!(existing)
      unless compatible_with?(existing)
        raise IdempotencyConflictError, "posting_key #{@posting_key} already used with different intent"
      end

      balance = StockBalance.find_by!(store_id: @store.id, product_variant_id: @product_variant.id)
      Result.new(ledger_entry: existing, stock_balance: balance, replayed: true)
    end

    def compatible_with?(existing)
      existing.store_id == @store.id &&
        existing.product_variant_id == @product_variant.id &&
        existing.movement_type == @movement_type &&
        existing.quantity_delta == @quantity_delta &&
        existing.source_type == @source.class.name &&
        existing.source_id == @source.id &&
        existing.reason_code.to_s == @reason_code.to_s &&
        existing.reason_note.to_s == @reason_note.to_s &&
        existing.estimate_department_id == @estimate_department&.id &&
        existing.estimate_regular_price_cents == @estimate_regular_price_cents &&
        existing.estimate_margin_bps == @estimate_margin_bps &&
        existing.estimate_unit_cost_cents == @estimate_unit_cost_cents &&
        financial_inputs_match?(existing)
    end

    def financial_inputs_match?(existing)
      case @movement_kind
      when :cost_correction
        existing.resulting_inventory_value_cents == @corrected_inventory_value_cents.to_i &&
          existing.cost_method == (@incoming_cost_method.presence || "explicit").to_s &&
          existing.cost_quality == (@incoming_cost_quality.presence || "actual").to_s
      when :opening_inventory, :customer_return, :customer_return_discard
        opening_inputs_match?(existing)
      when :quantity_only, :sale
        true
      else
        false
      end
    end

    def opening_inputs_match?(existing)
      if @incoming_unit_cost_cents.nil?
        return existing.unit_cost_cents.nil?
      end

      method = (@incoming_cost_method.presence || "explicit").to_s
      quality = (@incoming_cost_quality.presence || "actual").to_s

      existing.unit_cost_cents == @incoming_unit_cost_cents.to_i &&
        existing.cost_method == method &&
        existing.cost_quality == quality
    end
  end
end
