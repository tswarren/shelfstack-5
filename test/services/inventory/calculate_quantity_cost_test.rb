# frozen_string_literal: true

require "test_helper"

module Inventory
  class CalculateQuantityCostTest < ActiveSupport::TestCase
    test "first positive from zero initializes value and average" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 0,
        prior_inventory_value_cents: 0,
        prior_moving_average_cost_cents: nil,
        prior_cost_quality: "unknown",
        quantity_delta: 4,
        movement_kind: :opening_inventory,
        incoming_unit_cost_cents: 250,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual"
      )

      assert_equal 4, result.resulting_on_hand
      assert_equal 1000, result.resulting_inventory_value_cents
      assert_equal 250, result.resulting_moving_average_cost_cents
      assert_equal "actual", result.resulting_cost_quality
      assert_equal 1000, result.inventory_value_delta_cents
    end

    test "customer_return blends restored original cost into the moving average" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 4,
        prior_inventory_value_cents: 1000,
        prior_moving_average_cost_cents: 250,
        prior_cost_quality: "actual",
        quantity_delta: 1,
        movement_kind: :customer_return,
        incoming_unit_cost_cents: 250,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual"
      )

      assert_equal 5, result.resulting_on_hand
      assert_equal 1250, result.resulting_inventory_value_cents
      assert_equal 250, result.resulting_moving_average_cost_cents
      assert_equal "actual", result.resulting_cost_quality
      assert_equal 250, result.inventory_value_delta_cents
      assert_equal 250, result.unit_cost_cents
    end

    test "customer_return into a zero balance initializes value from the returned cost" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 0,
        prior_inventory_value_cents: 0,
        prior_moving_average_cost_cents: nil,
        prior_cost_quality: "unknown",
        quantity_delta: 1,
        movement_kind: :customer_return,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual"
      )

      assert_equal 1, result.resulting_on_hand
      assert_equal 500, result.resulting_inventory_value_cents
      assert_equal 500, result.resulting_moving_average_cost_cents
      assert_equal "actual", result.resulting_cost_quality
    end

    test "customer_return_discard removes exact returned cost without changing pre-existing valuation" do
      # Pre-existing: 10 @ $10 = $100. Return inbound at $5 then discard that $5 unit.
      after_return = CalculateQuantityCost.call(
        prior_on_hand: 10,
        prior_inventory_value_cents: 10_000,
        prior_moving_average_cost_cents: 1000,
        prior_cost_quality: "actual",
        quantity_delta: 1,
        movement_kind: :customer_return,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual"
      )
      assert_equal 11, after_return.resulting_on_hand
      assert_equal 10_500, after_return.resulting_inventory_value_cents

      discard = CalculateQuantityCost.call(
        prior_on_hand: after_return.resulting_on_hand,
        prior_inventory_value_cents: after_return.resulting_inventory_value_cents,
        prior_moving_average_cost_cents: after_return.resulting_moving_average_cost_cents,
        prior_cost_quality: after_return.resulting_cost_quality,
        quantity_delta: -1,
        movement_kind: :customer_return_discard,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual"
      )

      assert_equal 10, discard.resulting_on_hand
      assert_equal 10_000, discard.resulting_inventory_value_cents
      assert_equal 1000, discard.resulting_moving_average_cost_cents
      assert_equal 500, discard.unit_cost_cents
      assert_equal 500, discard.movement_cost_cents
      assert_equal(-500, discard.inventory_value_delta_cents)
    end

    test "unknown opening from zero leaves unknown positive value" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 0,
        prior_inventory_value_cents: 0,
        prior_moving_average_cost_cents: nil,
        prior_cost_quality: "unknown",
        quantity_delta: 2,
        movement_kind: :opening_inventory,
        incoming_unit_cost_cents: nil,
        incoming_cost_method: "unknown",
        incoming_cost_quality: "unknown"
      )

      assert_equal 2, result.resulting_on_hand
      assert_nil result.resulting_inventory_value_cents
      assert_equal "unknown", result.resulting_cost_quality
      assert_nil result.inventory_value_delta_cents
    end

    test "quantity-only outbound allocates proportional share" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 4,
        prior_inventory_value_cents: 1000,
        prior_moving_average_cost_cents: 250,
        prior_cost_quality: "actual",
        quantity_delta: -1,
        movement_kind: :quantity_only
      )

      assert_equal 3, result.resulting_on_hand
      assert_equal 750, result.resulting_inventory_value_cents
      assert_equal(-250, result.inventory_value_delta_cents)
      assert_equal "moving_average", result.cost_method
    end

    test "quantity-only depleting remainder consumes residual value" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 3,
        prior_inventory_value_cents: 1000,
        prior_moving_average_cost_cents: 333,
        prior_cost_quality: "actual",
        quantity_delta: -3,
        movement_kind: :quantity_only
      )

      assert_equal 0, result.resulting_on_hand
      assert_equal 0, result.resulting_inventory_value_cents
      assert_nil result.resulting_moving_average_cost_cents
      assert_equal "unknown", result.resulting_cost_quality
      assert_equal(-1000, result.inventory_value_delta_cents)
    end

    test "crossing into deficit zeros asset value" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 2,
        prior_inventory_value_cents: 500,
        prior_moving_average_cost_cents: 250,
        prior_cost_quality: "actual",
        quantity_delta: -5,
        movement_kind: :quantity_only
      )

      assert_equal(-3, result.resulting_on_hand)
      assert_equal 0, result.resulting_inventory_value_cents
      assert_equal "unknown", result.resulting_cost_quality
      assert_equal(-500, result.inventory_value_delta_cents)
    end

    test "surplus after deficit is unknown in phase 3" do
      result = CalculateQuantityCost.call(
        prior_on_hand: -2,
        prior_inventory_value_cents: 0,
        prior_moving_average_cost_cents: nil,
        prior_cost_quality: "unknown",
        quantity_delta: 5,
        movement_kind: :quantity_only
      )

      assert_equal 3, result.resulting_on_hand
      assert_nil result.resulting_inventory_value_cents
      assert_equal "unknown", result.resulting_cost_quality
    end

    test "cost correction uses aggregate corrected value" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 3,
        prior_inventory_value_cents: 900,
        prior_moving_average_cost_cents: 300,
        prior_cost_quality: "estimated",
        quantity_delta: 0,
        movement_kind: :cost_correction,
        corrected_inventory_value_cents: 1000,
        incoming_cost_quality: "actual",
        incoming_cost_method: "explicit"
      )

      assert_equal 3, result.resulting_on_hand
      assert_equal 1000, result.resulting_inventory_value_cents
      assert_equal 100, result.inventory_value_delta_cents
      assert_equal 333, result.resulting_moving_average_cost_cents
      assert_equal "actual", result.resulting_cost_quality
      assert_nil result.movement_cost_cents
    end

    test "cost correction rejects nil corrected value" do
      assert_raises(ArgumentError) do
        CalculateQuantityCost.call(
          prior_on_hand: 3,
          prior_inventory_value_cents: 900,
          prior_moving_average_cost_cents: 300,
          prior_cost_quality: "actual",
          quantity_delta: 0,
          movement_kind: :cost_correction,
          corrected_inventory_value_cents: nil
        )
      end
    end

    test "department estimate formula round half up" do
      assert_equal 750, Rounding.round_half_up(1000 * (10_000 - 2500), 10_000)
    end

    test "quantity-only inbound uses aggregate share not rounded unit times qty" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 3,
        prior_inventory_value_cents: 100,
        prior_moving_average_cost_cents: 33,
        prior_cost_quality: "actual",
        quantity_delta: 3,
        movement_kind: :quantity_only
      )

      assert_equal 6, result.resulting_on_hand
      assert_equal 100, result.inventory_value_delta_cents
      assert_equal 200, result.resulting_inventory_value_cents
    end

    test "cost correction from unknown prior records null value delta" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 3,
        prior_inventory_value_cents: nil,
        prior_moving_average_cost_cents: nil,
        prior_cost_quality: "unknown",
        quantity_delta: 0,
        movement_kind: :cost_correction,
        corrected_inventory_value_cents: 1000,
        incoming_cost_quality: "actual",
        incoming_cost_method: "explicit"
      )

      assert_nil result.inventory_value_delta_cents
      assert_equal 1000, result.resulting_inventory_value_cents
      assert_equal "actual", result.resulting_cost_quality
    end

    test "known opening into unknown balance keeps unknown value but records provenance" do
      result = CalculateQuantityCost.call(
        prior_on_hand: 2,
        prior_inventory_value_cents: nil,
        prior_moving_average_cost_cents: nil,
        prior_cost_quality: "unknown",
        quantity_delta: 1,
        movement_kind: :opening_inventory,
        incoming_unit_cost_cents: 500,
        incoming_cost_method: "explicit",
        incoming_cost_quality: "actual"
      )

      assert_nil result.resulting_inventory_value_cents
      assert_nil result.inventory_value_delta_cents
      assert_equal "unknown", result.resulting_cost_quality
      assert_equal 500, result.unit_cost_cents
      assert_equal 500, result.movement_cost_cents
      assert_equal "explicit", result.cost_method
      assert_equal "actual", result.cost_quality
    end
  end
end
