# frozen_string_literal: true

require "test_helper"

class InventoryAdjustmentLineValidationTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @user = users(:admin)
    @variant = product_variants(:sample_book_standard)
  end

  test "rejects negative opening unit cost" do
    adjustment = draft("opening_inventory", inventory_adjustment_reasons(:opening_initial))
    line = adjustment.inventory_adjustment_lines.build(
      product_variant: @variant,
      position: 0,
      quantity_delta: 1,
      input_unit_cost_cents: -100,
      input_cost_method: "explicit",
      input_cost_quality: "actual"
    )

    refute line.valid?
    assert_includes line.errors[:input_unit_cost_cents], "must be greater than or equal to 0"
  end

  test "rejects unknown method with supplied unit cost" do
    adjustment = draft("opening_inventory", inventory_adjustment_reasons(:opening_initial))
    line = adjustment.inventory_adjustment_lines.build(
      product_variant: @variant,
      position: 0,
      quantity_delta: 1,
      input_unit_cost_cents: 100,
      input_cost_method: "unknown",
      input_cost_quality: "unknown"
    )

    refute line.valid?
  end

  test "rejects cost correction with unknown quality" do
    adjustment = draft("cost_correction", inventory_adjustment_reasons(:cost_documented), note: "doc")
    line = adjustment.inventory_adjustment_lines.build(
      product_variant: @variant,
      position: 0,
      quantity_delta: 0,
      corrected_inventory_value_cents: 1000,
      input_cost_method: "explicit",
      input_cost_quality: "unknown"
    )

    refute line.valid?
    assert_includes line.errors[:input_cost_quality].join, "actual"
  end

  test "rejects configured_estimate method on cost correction" do
    adjustment = draft("cost_correction", inventory_adjustment_reasons(:cost_documented), note: "doc")
    line = adjustment.inventory_adjustment_lines.build(
      product_variant: @variant,
      position: 0,
      quantity_delta: 0,
      corrected_inventory_value_cents: 1000,
      input_cost_method: "configured_estimate",
      input_cost_quality: "estimated"
    )

    refute line.valid?
  end

  private

  def draft(kind, reason, note: nil)
    InventoryAdjustment.create!(
      store: @store,
      kind: kind,
      status: "draft",
      inventory_adjustment_reason: reason,
      created_by_user: @user,
      note: note
    )
  end
end
