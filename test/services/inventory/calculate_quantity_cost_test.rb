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
  end
end
