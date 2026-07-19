# frozen_string_literal: true

module Inventory
  # Pure Phase 3 quantity-cost calculator. Must be called under a locked balance.
  class CalculateQuantityCost < ApplicationService
    Result = Data.define(
      :resulting_on_hand,
      :resulting_inventory_value_cents,
      :resulting_moving_average_cost_cents,
      :resulting_cost_quality,
      :inventory_value_delta_cents,
      :unit_cost_cents,
      :movement_cost_cents,
      :cost_method,
      :cost_quality,
      :update_last_known
    )

    KNOWN_QUALITIES = %w[actual estimated mixed].freeze

    def initialize(
      prior_on_hand:,
      prior_inventory_value_cents:,
      prior_moving_average_cost_cents:,
      prior_cost_quality:,
      quantity_delta:,
      movement_kind:,
      incoming_unit_cost_cents: nil,
      incoming_cost_method: nil,
      incoming_cost_quality: nil,
      corrected_inventory_value_cents: nil,
      prior_last_known_unit_cost_cents: nil,
      prior_last_known_cost_quality: nil
    )
      @prior_on_hand = prior_on_hand.to_i
      @prior_inventory_value_cents = prior_inventory_value_cents
      @prior_moving_average_cost_cents = prior_moving_average_cost_cents
      @prior_cost_quality = prior_cost_quality.to_s
      @quantity_delta = quantity_delta.to_i
      @movement_kind = movement_kind.to_sym
      @incoming_unit_cost_cents = incoming_unit_cost_cents
      @incoming_cost_method = incoming_cost_method
      @incoming_cost_quality = incoming_cost_quality
      @corrected_inventory_value_cents = corrected_inventory_value_cents
      @prior_last_known_unit_cost_cents = prior_last_known_unit_cost_cents
      @prior_last_known_cost_quality = prior_last_known_cost_quality
    end

    def call
      case @movement_kind
      when :cost_correction
        calculate_cost_correction
      when :sale
        calculate_sale
      when :customer_return_discard
        calculate_customer_return_discard
      when :opening_inventory, :quantity_only, :customer_return
        calculate_quantity_movement
      else
        raise ArgumentError, "unsupported movement_kind: #{@movement_kind}"
      end
    end

    private

    # Linked-return discard: remove the exact historical cost that the preceding
    # customer_return inbound introduced so pre-existing stock valuation is unchanged.
    def calculate_customer_return_discard
      raise ArgumentError, "quantity_delta must be negative for customer_return_discard" unless @quantity_delta.negative?
      if @incoming_unit_cost_cents.nil?
        raise ArgumentError, "incoming_unit_cost_cents is required for customer_return_discard"
      end

      removed = -@quantity_delta
      resulting_on_hand = @prior_on_hand + @quantity_delta
      unit = @incoming_unit_cost_cents.to_i
      raise ArgumentError, "incoming_unit_cost_cents must be >= 0" if unit.negative?

      movement_cost = unit * removed
      method = (@incoming_cost_method.presence || "explicit").to_s
      quality = (@incoming_cost_quality.presence || "actual").to_s

      if @prior_on_hand <= 0 || prior_valuation_unknown?
        return zero_asset_result(
          resulting_on_hand,
          cost_method: method,
          cost_quality: quality,
          unit_cost_cents: unit,
          movement_cost_cents: movement_cost,
          inventory_value_delta_cents: -movement_cost
        )
      end

      prior_value = @prior_inventory_value_cents.to_i
      resulting_value = prior_value - movement_cost
      raise ArgumentError, "discard would drive inventory value negative" if resulting_value.negative?

      if resulting_on_hand.positive?
        average = Rounding.round_half_up(resulting_value, resulting_on_hand)
        Result.new(
          resulting_on_hand: resulting_on_hand,
          resulting_inventory_value_cents: resulting_value,
          resulting_moving_average_cost_cents: average,
          resulting_cost_quality: @prior_cost_quality,
          inventory_value_delta_cents: -movement_cost,
          unit_cost_cents: unit,
          movement_cost_cents: movement_cost,
          cost_method: method,
          cost_quality: quality,
          update_last_known: false
        )
      else
        Result.new(
          resulting_on_hand: resulting_on_hand,
          resulting_inventory_value_cents: 0,
          resulting_moving_average_cost_cents: nil,
          resulting_cost_quality: "unknown",
          inventory_value_delta_cents: -prior_value,
          unit_cost_cents: unit,
          movement_cost_cents: movement_cost,
          cost_method: method,
          cost_quality: quality,
          update_last_known: false
        )
      end
    end

    def calculate_cost_correction
      raise ArgumentError, "quantity_delta must be zero for cost correction" unless @quantity_delta.zero?
      raise ArgumentError, "cost correction requires positive on_hand" unless @prior_on_hand.positive?
      if @corrected_inventory_value_cents.nil?
        raise ArgumentError, "corrected_inventory_value_cents is required"
      end

      corrected = @corrected_inventory_value_cents.to_i
      raise ArgumentError, "corrected_inventory_value_cents must be >= 0" if corrected.negative?

      quality = (@incoming_cost_quality.presence || "actual").to_s
      method = (@incoming_cost_method.presence || "explicit").to_s
      average = corrected.zero? ? 0 : Rounding.round_half_up(corrected, @prior_on_hand)

      # Prior unknown valuation → delta is unknown (null), not "corrected - 0".
      delta = if prior_valuation_unknown?
        nil
      else
        corrected - @prior_inventory_value_cents.to_i
      end

      Result.new(
        resulting_on_hand: @prior_on_hand,
        resulting_inventory_value_cents: corrected,
        resulting_moving_average_cost_cents: average,
        resulting_cost_quality: quality,
        inventory_value_delta_cents: delta,
        unit_cost_cents: average,
        movement_cost_cents: nil,
        cost_method: method,
        cost_quality: quality,
        update_last_known: KNOWN_QUALITIES.include?(quality)
      )
    end

    def calculate_quantity_movement
      resulting_on_hand = @prior_on_hand + @quantity_delta

      if @quantity_delta.positive?
        calculate_inbound(resulting_on_hand)
      elsif @quantity_delta.negative?
        calculate_outbound(resulting_on_hand)
      else
        raise ArgumentError, "quantity_delta must be non-zero for quantity movements"
      end
    end

    def calculate_inbound(resulting_on_hand)
      if @movement_kind == :quantity_only
        calculate_quantity_only_inbound(resulting_on_hand)
      else
        calculate_opening_inbound(resulting_on_hand)
      end
    end

    def calculate_opening_inbound(resulting_on_hand)
      unknown = unknown_incoming?

      if @prior_on_hand <= 0
        if resulting_on_hand <= 0
          return zero_asset_result(resulting_on_hand, cost_method: "unknown", cost_quality: "unknown",
                                                     unit_cost_cents: nil, movement_cost_cents: nil,
                                                     inventory_value_delta_cents: 0)
        end

        if @prior_on_hand.negative?
          return unknown_positive_result(resulting_on_hand, incoming_provenance: incoming_provenance_when_known)
        end

        return unknown_positive_result(resulting_on_hand, incoming_provenance: incoming_provenance_when_known) if unknown

        unit = @incoming_unit_cost_cents.to_i
        value = Rounding.multiply_round_half_up(unit, resulting_on_hand)
        quality = @incoming_cost_quality.to_s
        method = (@incoming_cost_method.presence || "explicit").to_s

        Result.new(
          resulting_on_hand: resulting_on_hand,
          resulting_inventory_value_cents: value,
          resulting_moving_average_cost_cents: unit,
          resulting_cost_quality: quality,
          inventory_value_delta_cents: value,
          unit_cost_cents: unit,
          movement_cost_cents: value,
          cost_method: method,
          cost_quality: quality,
          update_last_known: KNOWN_QUALITIES.include?(quality)
        )
      elsif prior_valuation_unknown? || unknown
        # Balance remains unknown; still record documented incoming cost provenance on the movement.
        unknown_positive_result(resulting_on_hand, incoming_provenance: incoming_provenance_when_known)
      else
        unit = @incoming_unit_cost_cents.to_i
        incoming_value = Rounding.multiply_round_half_up(unit, @quantity_delta)
        prior_value = @prior_inventory_value_cents.to_i
        resulting_value = prior_value + incoming_value
        average = Rounding.round_half_up(resulting_value, resulting_on_hand)
        quality = aggregate_quality(@prior_cost_quality, @incoming_cost_quality.to_s)
        method = (@incoming_cost_method.presence || "explicit").to_s

        Result.new(
          resulting_on_hand: resulting_on_hand,
          resulting_inventory_value_cents: resulting_value,
          resulting_moving_average_cost_cents: average,
          resulting_cost_quality: quality,
          inventory_value_delta_cents: incoming_value,
          unit_cost_cents: unit,
          movement_cost_cents: incoming_value,
          cost_method: method,
          cost_quality: @incoming_cost_quality.to_s,
          update_last_known: KNOWN_QUALITIES.include?(quality)
        )
      end
    end

    def calculate_quantity_only_inbound(resulting_on_hand)
      if @prior_on_hand < 0
        if resulting_on_hand <= 0
          return zero_asset_result(resulting_on_hand, cost_method: "unknown", cost_quality: "unknown",
                                                     unit_cost_cents: nil, movement_cost_cents: nil,
                                                     inventory_value_delta_cents: 0)
        end
        return unknown_positive_result(resulting_on_hand)
      end

      if @prior_on_hand.zero?
        return unknown_positive_result(resulting_on_hand)
      end

      if prior_valuation_unknown?
        return unknown_positive_result(resulting_on_hand)
      end

      prior_value = @prior_inventory_value_cents.to_i
      # Aggregate-authoritative share of current value for the added quantity.
      incoming_value = Rounding.round_half_up(prior_value * @quantity_delta, @prior_on_hand)
      resulting_value = prior_value + incoming_value
      average = Rounding.round_half_up(resulting_value, resulting_on_hand)
      unit = Rounding.round_half_up(incoming_value, @quantity_delta)

      Result.new(
        resulting_on_hand: resulting_on_hand,
        resulting_inventory_value_cents: resulting_value,
        resulting_moving_average_cost_cents: average,
        resulting_cost_quality: @prior_cost_quality,
        inventory_value_delta_cents: incoming_value,
        unit_cost_cents: unit,
        movement_cost_cents: incoming_value,
        cost_method: "moving_average",
        cost_quality: @prior_cost_quality,
        update_last_known: false
      )
    end

    def calculate_outbound(resulting_on_hand)
      removed = -@quantity_delta

      if @prior_on_hand <= 0
        return zero_asset_result(resulting_on_hand, cost_method: "unknown", cost_quality: "unknown",
                                                   unit_cost_cents: nil, movement_cost_cents: nil,
                                                   inventory_value_delta_cents: 0)
      end

      if prior_valuation_unknown?
        if resulting_on_hand <= 0
          return zero_asset_result(resulting_on_hand, cost_method: "unknown", cost_quality: "unknown",
                                                     unit_cost_cents: nil, movement_cost_cents: nil,
                                                     inventory_value_delta_cents: nil)
        end

        return Result.new(
          resulting_on_hand: resulting_on_hand,
          resulting_inventory_value_cents: nil,
          resulting_moving_average_cost_cents: nil,
          resulting_cost_quality: "unknown",
          inventory_value_delta_cents: nil,
          unit_cost_cents: nil,
          movement_cost_cents: nil,
          cost_method: "unknown",
          cost_quality: "unknown",
          update_last_known: false
        )
      end

      prior_value = @prior_inventory_value_cents.to_i
      positive_consumed = [ removed, @prior_on_hand ].min

      if resulting_on_hand.positive?
        allocated = Rounding.round_half_up(prior_value * positive_consumed, @prior_on_hand)
        resulting_value = prior_value - allocated
        average = Rounding.round_half_up(resulting_value, resulting_on_hand)
        unit = Rounding.round_half_up(allocated, positive_consumed)

        Result.new(
          resulting_on_hand: resulting_on_hand,
          resulting_inventory_value_cents: resulting_value,
          resulting_moving_average_cost_cents: average,
          resulting_cost_quality: @prior_cost_quality,
          inventory_value_delta_cents: -allocated,
          unit_cost_cents: unit,
          movement_cost_cents: allocated,
          cost_method: "moving_average",
          cost_quality: @prior_cost_quality,
          update_last_known: false
        )
      else
        Result.new(
          resulting_on_hand: resulting_on_hand,
          resulting_inventory_value_cents: 0,
          resulting_moving_average_cost_cents: nil,
          resulting_cost_quality: "unknown",
          inventory_value_delta_cents: -prior_value,
          unit_cost_cents: positive_consumed.positive? ? Rounding.round_half_up(prior_value, positive_consumed) : nil,
          movement_cost_cents: prior_value,
          cost_method: "moving_average",
          cost_quality: @prior_cost_quality,
          update_last_known: false
        )
      end
    end

    # OD-014 Phase 4c interim: an outbound sale carries a *provisional* unit cost
    # (current moving average, else last-known positive carrying rate, else unknown)
    # on the ledger/line cost snapshot even when the balance's own resulting asset
    # value must stay zero (ADR-0013 zero/negative On Hand rule). Sale never crosses
    # zero and back positive in one movement (quantity_delta is always outbound), so
    # a sale beyond On Hand may leave On Hand negative with no settlement performed
    # here (Phase 5 concern).
    def calculate_sale
      raise ArgumentError, "quantity_delta must be negative for a sale" unless @quantity_delta.negative?

      removed = -@quantity_delta
      resulting_on_hand = @prior_on_hand + @quantity_delta
      source = resolve_sale_cost_source(removed)

      if resulting_on_hand.positive?
        calculate_sale_resulting_positive(resulting_on_hand, removed, source)
      else
        calculate_sale_resulting_nonpositive(resulting_on_hand, source)
      end
    end

    def calculate_sale_resulting_positive(resulting_on_hand, removed, source)
      unless source[:from_current_average]
        return Result.new(
          resulting_on_hand: resulting_on_hand, resulting_inventory_value_cents: nil,
          resulting_moving_average_cost_cents: nil, resulting_cost_quality: "unknown",
          inventory_value_delta_cents: nil, unit_cost_cents: source[:unit_cost_cents],
          movement_cost_cents: source[:movement_cost_cents], cost_method: source[:cost_method],
          cost_quality: source[:cost_quality], update_last_known: false
        )
      end

      prior_value = @prior_inventory_value_cents.to_i
      allocated = Rounding.round_half_up(prior_value * removed, @prior_on_hand)
      resulting_value = prior_value - allocated
      average = Rounding.round_half_up(resulting_value, resulting_on_hand)

      Result.new(
        resulting_on_hand: resulting_on_hand, resulting_inventory_value_cents: resulting_value,
        resulting_moving_average_cost_cents: average, resulting_cost_quality: @prior_cost_quality,
        inventory_value_delta_cents: -allocated, unit_cost_cents: source[:unit_cost_cents],
        movement_cost_cents: source[:movement_cost_cents], cost_method: source[:cost_method],
        cost_quality: source[:cost_quality], update_last_known: false
      )
    end

    def calculate_sale_resulting_nonpositive(resulting_on_hand, source)
      delta = if @prior_on_hand.positive? && source[:from_current_average]
        -@prior_inventory_value_cents.to_i
      elsif @prior_on_hand.positive?
        nil
      else
        0
      end

      Result.new(
        resulting_on_hand: resulting_on_hand, resulting_inventory_value_cents: 0,
        resulting_moving_average_cost_cents: nil, resulting_cost_quality: "unknown",
        inventory_value_delta_cents: delta, unit_cost_cents: source[:unit_cost_cents],
        movement_cost_cents: source[:movement_cost_cents], cost_method: source[:cost_method],
        cost_quality: source[:cost_quality], update_last_known: false
      )
    end

    # Resolves the provisional per-unit sale cost: current aggregate moving average
    # when a known positive balance exists; otherwise the last documented positive
    # carrying rate; otherwise unknown (OD-014).
    def resolve_sale_cost_source(removed)
      if @prior_on_hand.positive? && !prior_valuation_unknown?
        unit = @prior_moving_average_cost_cents
        return {
          from_current_average: true, unit_cost_cents: unit,
          movement_cost_cents: Rounding.multiply_round_half_up(unit, removed),
          cost_method: "moving_average", cost_quality: @prior_cost_quality
        }
      end

      if @prior_last_known_unit_cost_cents.present? && KNOWN_QUALITIES.include?(@prior_last_known_cost_quality.to_s)
        unit = @prior_last_known_unit_cost_cents
        return {
          from_current_average: false, unit_cost_cents: unit,
          movement_cost_cents: Rounding.multiply_round_half_up(unit, removed),
          cost_method: "last_known", cost_quality: @prior_last_known_cost_quality.to_s
        }
      end

      { from_current_average: false, unit_cost_cents: nil, movement_cost_cents: nil,
        cost_method: "unknown", cost_quality: "unknown" }
    end

    def unknown_incoming?
      @incoming_cost_quality.to_s == "unknown" ||
        @incoming_cost_method.to_s == "unknown" ||
        @incoming_unit_cost_cents.nil?
    end

    def prior_valuation_unknown?
      @prior_cost_quality == "unknown" || @prior_inventory_value_cents.nil?
    end

    def incoming_provenance_when_known
      return nil if unknown_incoming?

      {
        unit_cost_cents: @incoming_unit_cost_cents.to_i,
        movement_cost_cents: Rounding.multiply_round_half_up(@incoming_unit_cost_cents, @quantity_delta),
        cost_method: (@incoming_cost_method.presence || "explicit").to_s,
        cost_quality: @incoming_cost_quality.to_s
      }
    end

    def aggregate_quality(existing, incoming)
      return "unknown" if existing == "unknown" || incoming == "unknown"
      return "mixed" if existing == "mixed" || incoming == "mixed"
      return existing if existing == incoming

      "mixed"
    end

    def unknown_positive_result(resulting_on_hand, incoming_provenance: nil)
      Result.new(
        resulting_on_hand: resulting_on_hand,
        resulting_inventory_value_cents: nil,
        resulting_moving_average_cost_cents: nil,
        resulting_cost_quality: "unknown",
        inventory_value_delta_cents: nil,
        unit_cost_cents: incoming_provenance&.dig(:unit_cost_cents),
        movement_cost_cents: incoming_provenance&.dig(:movement_cost_cents),
        cost_method: incoming_provenance&.dig(:cost_method) || "unknown",
        cost_quality: incoming_provenance&.dig(:cost_quality) || "unknown",
        update_last_known: false
      )
    end

    def zero_asset_result(resulting_on_hand, cost_method:, cost_quality:, unit_cost_cents:, movement_cost_cents:, inventory_value_delta_cents:)
      Result.new(
        resulting_on_hand: resulting_on_hand,
        resulting_inventory_value_cents: 0,
        resulting_moving_average_cost_cents: nil,
        resulting_cost_quality: "unknown",
        inventory_value_delta_cents: inventory_value_delta_cents,
        unit_cost_cents: unit_cost_cents,
        movement_cost_cents: movement_cost_cents,
        cost_method: cost_method,
        cost_quality: cost_quality,
        update_last_known: false
      )
    end
  end
end
