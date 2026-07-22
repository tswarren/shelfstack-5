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
      unavailable_delta: 0,
      availability_reason: nil,
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
      @unavailable_delta = unavailable_delta.to_i
      @availability_reason = availability_reason
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

        deficit = compute_deficit_effect(balance, calc)
        resulting_unavailable = balance.unavailable + @unavailable_delta
        if resulting_unavailable.negative?
          raise Error, "unavailable cannot become negative"
        end

        prior_pool = balance.open_provisional_deficit_cost_cents
        prior_deficit_quality = balance.deficit_cost_quality

        entry = InventoryLedgerEntry.create!(
          store: @store,
          product_variant: @product_variant,
          movement_type: @movement_type,
          quantity_delta: @quantity_delta,
          unavailable_delta: @unavailable_delta,
          resulting_unavailable: resulting_unavailable,
          availability_reason: @availability_reason,
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
          provisional_cost_released_cents: deficit.provisional_cost_released_cents,
          provisional_deficit_cost_quality_snapshot: deficit.provisional_deficit_cost_quality_snapshot,
          prior_open_provisional_deficit_cost_cents: deficit.changed ? prior_pool : nil,
          resulting_open_provisional_deficit_cost_cents: deficit.changed ? deficit.resulting_open_provisional_deficit_cost_cents : nil,
          prior_deficit_cost_quality: deficit.changed ? prior_deficit_quality : nil,
          resulting_deficit_cost_quality: deficit.changed ? deficit.resulting_deficit_cost_quality : nil,
          settlement_variance_cents: deficit.settlement_variance_cents,
          settlement_variance_kind: deficit.settlement_variance_kind,
          posting_key: @posting_key,
          posted_by_user: @posted_by_user,
          posted_at: @posted_at
        )

        apply_balance!(balance, calc, deficit, resulting_unavailable)
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
      when "receipt" then :receipt
      when "receipt_deficit_settlement" then :receipt_deficit_settlement
      else
        raise Error, "unsupported movement_type: #{@movement_type}"
      end
    end

    def apply_balance!(balance, calc, deficit, resulting_unavailable)
      attrs = {
        on_hand: calc.resulting_on_hand,
        unavailable: resulting_unavailable,
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

      if deficit.changed
        attrs[:open_provisional_deficit_cost_cents] = deficit.resulting_open_provisional_deficit_cost_cents
        attrs[:deficit_cost_quality] = deficit.resulting_deficit_cost_quality
      end

      balance.update!(attrs)
    end

    DeficitEffect = Data.define(
      :changed,
      :resulting_open_provisional_deficit_cost_cents,
      :resulting_deficit_cost_quality,
      :provisional_cost_released_cents,
      :provisional_deficit_cost_quality_snapshot,
      :settlement_variance_cents,
      :settlement_variance_kind
    )
    private_constant :DeficitEffect

    NO_DEFICIT_EFFECT = DeficitEffect.new(
      changed: false,
      resulting_open_provisional_deficit_cost_cents: nil,
      resulting_deficit_cost_quality: nil,
      provisional_cost_released_cents: nil,
      provisional_deficit_cost_quality_snapshot: nil,
      settlement_variance_cents: nil,
      settlement_variance_kind: nil
    )
    private_constant :NO_DEFICIT_EFFECT

    # Public for exact reversals (ReverseLedgerEntry) that share OD-014 pool math.
    def self.deficit_effect_for(balance:, resulting_on_hand:, movement_type:, unit_cost_cents:, cost_quality:, incoming_unit_cost_cents: nil)
      poster = allocate
      poster.instance_variable_set(:@movement_type, movement_type.to_s)
      poster.instance_variable_set(:@incoming_unit_cost_cents, incoming_unit_cost_cents)
      calc = Struct.new(:resulting_on_hand, :unit_cost_cents, :cost_quality).new(
        resulting_on_hand, unit_cost_cents, cost_quality
      )
      poster.send(:compute_deficit_effect, balance, calc)
    end

    # OD-014: negative On Hand is an aggregate Store-and-Variant deficit-cost
    # pool, never matched to individual outbound movements. Any movement that
    # changes the open deficit quantity (max(-on_hand, 0)) either adds
    # provisional cost to the pool (outbound, deficit grows) or releases cost
    # from it proportionally (inbound, deficit shrinks). Movements that do not
    # cross the deficit boundary leave the pool untouched.
    def compute_deficit_effect(balance, calc)
      prior_deficit_quantity = [ -balance.on_hand, 0 ].max
      resulting_deficit_quantity = [ -calc.resulting_on_hand, 0 ].max

      if resulting_deficit_quantity > prior_deficit_quantity
        deficit_created_effect(balance, calc, resulting_deficit_quantity - prior_deficit_quantity)
      elsif resulting_deficit_quantity < prior_deficit_quantity
        deficit_released_effect(
          balance, prior_deficit_quantity, resulting_deficit_quantity,
          prior_deficit_quantity - resulting_deficit_quantity
        )
      else
        NO_DEFICIT_EFFECT
      end
    end

    def deficit_created_effect(balance, calc, created_quantity)
      known = calc.unit_cost_cents.present? && CalculateQuantityCost::KNOWN_QUALITIES.include?(calc.cost_quality.to_s)
      prior_deficit_quantity = [ -balance.on_hand, 0 ].max
      prior_pool = balance.open_provisional_deficit_cost_cents
      prior_quality = balance.deficit_cost_quality

      if prior_deficit_quantity.zero?
        resulting_pool = known ? Rounding.multiply_round_half_up(calc.unit_cost_cents, created_quantity) : nil
        resulting_quality = known ? calc.cost_quality.to_s : "unknown"
      elsif known && prior_pool.present? && prior_quality != "unknown"
        resulting_pool = prior_pool + Rounding.multiply_round_half_up(calc.unit_cost_cents, created_quantity)
        resulting_quality = merge_deficit_quality(prior_quality, calc.cost_quality.to_s)
      else
        resulting_pool = nil
        resulting_quality = "unknown"
      end

      DeficitEffect.new(
        changed: true,
        resulting_open_provisional_deficit_cost_cents: resulting_pool,
        resulting_deficit_cost_quality: resulting_quality,
        provisional_cost_released_cents: nil,
        provisional_deficit_cost_quality_snapshot: nil,
        settlement_variance_cents: nil,
        settlement_variance_kind: nil
      )
    end

    def deficit_released_effect(balance, prior_deficit_quantity, resulting_deficit_quantity, settled_quantity)
      prior_pool = balance.open_provisional_deficit_cost_cents
      prior_quality = balance.deficit_cost_quality

      if resulting_deficit_quantity.zero?
        released = prior_pool
        resulting_pool = 0
        resulting_quality = "unknown"
      else
        released = prior_pool.nil? ? nil : Rounding.round_half_up(prior_pool * settled_quantity, prior_deficit_quantity)
        resulting_pool = prior_pool.nil? ? nil : prior_pool - released
        resulting_quality = prior_quality
      end

      variance, variance_kind = settlement_variance(released, settled_quantity)

      DeficitEffect.new(
        changed: true,
        resulting_open_provisional_deficit_cost_cents: resulting_pool,
        resulting_deficit_cost_quality: resulting_quality,
        provisional_cost_released_cents: released,
        provisional_deficit_cost_quality_snapshot: prior_quality,
        settlement_variance_cents: variance,
        settlement_variance_kind: variance_kind
      )
    end

    # Only an actual receipt settlement carries a distinct "actual settlement
    # cost" to compare against the released provisional cost (OD-014
    # "Known costs" / "Unknown provisional cost"). Linked returns/post-voids
    # and quantity-only corrections release the pool using its own recorded
    # cost and never create ordinary receipt cost variance.
    def settlement_variance(released, settled_quantity)
      return [ nil, nil ] unless @movement_type == "receipt_deficit_settlement"

      actual_settlement_cost = if @incoming_unit_cost_cents.present?
        Rounding.multiply_round_half_up(@incoming_unit_cost_cents, settled_quantity)
      end

      return [ nil, nil ] if actual_settlement_cost.nil?
      return [ nil, "late_cost_recognition" ] if released.nil?

      [ actual_settlement_cost - released, "ordinary" ]
    end

    def merge_deficit_quality(existing, incoming)
      return "unknown" if existing == "unknown" || incoming == "unknown"
      return "mixed" if existing == "mixed" || incoming == "mixed"
      return existing if existing == incoming

      "mixed"
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
        existing.unavailable_delta.to_i == @unavailable_delta &&
        existing.availability_reason.to_s == @availability_reason.to_s &&
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
      when :opening_inventory, :customer_return, :customer_return_discard, :receipt, :receipt_deficit_settlement
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
