# frozen_string_literal: true

require "test_helper"

class InventoryAdjustmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
    @reason = inventory_adjustment_reasons(:opening_other)
    @variant = product_variants(:sample_book_standard)
  end

  test "new form emits nested line attribute field names" do
    get new_inventory_adjustment_path
    assert_response :success
    assert_select "select[name='inventory_adjustment[inventory_adjustment_lines_attributes][0][product_variant_id]']"
    assert_select "input[name='inventory_adjustment[inventory_adjustment_lines_attributes][0][quantity_delta]']"
  end

  test "create persists adjustment line from nested attributes" do
    assert_difference([ "InventoryAdjustment.count", "InventoryAdjustmentLine.count" ]) do
      post inventory_adjustments_path, params: {
        inventory_adjustment: {
          kind: "opening_inventory",
          inventory_adjustment_reason_id: @reason.id,
          note: "",
          inventory_adjustment_lines_attributes: {
            "0" => {
              product_variant_id: @variant.id,
              quantity_delta: 1,
              input_unit_cost_cents: 100,
              input_cost_method: "explicit",
              input_cost_quality: "actual",
              position: 0
            }
          }
        }
      }
    end

    adjustment = InventoryAdjustment.order(:id).last
    assert_equal "draft", adjustment.status
    assert_equal 1, adjustment.inventory_adjustment_lines.count
    line = adjustment.inventory_adjustment_lines.first
    assert_equal @variant.id, line.product_variant_id
    assert_equal 1, line.quantity_delta
    assert_equal 100, line.input_unit_cost_cents
    assert_redirected_to inventory_adjustment_path(adjustment)
  end

  test "update replaces draft lines from nested attributes" do
    adjustment = InventoryAdjustment.create!(
      store: stores(:main_street),
      kind: "opening_inventory",
      status: "draft",
      inventory_adjustment_reason: @reason,
      created_by_user: users(:admin)
    )

    assert_difference("InventoryAdjustmentLine.count", 1) do
      patch inventory_adjustment_path(adjustment), params: {
        inventory_adjustment: {
          kind: "opening_inventory",
          inventory_adjustment_reason_id: @reason.id,
          note: "Added line on update",
          inventory_adjustment_lines_attributes: {
            "0" => {
              product_variant_id: @variant.id,
              quantity_delta: 3,
              input_unit_cost_cents: 250,
              input_cost_method: "explicit",
              input_cost_quality: "actual",
              position: 0
            }
          }
        }
      }
    end

    adjustment.reload
    assert_equal 1, adjustment.inventory_adjustment_lines.count
    line = adjustment.inventory_adjustment_lines.first
    assert_equal 3, line.quantity_delta
    assert_equal 250, line.input_unit_cost_cents
    assert_equal "Added line on update", adjustment.note
    assert_redirected_to inventory_adjustment_path(adjustment)
  end

  test "create normalizes blank optional cost fields to nil" do
    assert_difference("InventoryAdjustmentLine.count") do
      post inventory_adjustments_path, params: {
        inventory_adjustment: {
          kind: "opening_inventory",
          inventory_adjustment_reason_id: inventory_adjustment_reasons(:opening_initial).id,
          note: "",
          inventory_adjustment_lines_attributes: {
            "0" => {
              product_variant_id: @variant.id,
              quantity_delta: 2,
              input_unit_cost_cents: "",
              input_cost_method: "",
              input_cost_quality: "",
              corrected_inventory_value_cents: "",
              position: 0
            }
          }
        }
      }
    end

    line = InventoryAdjustmentLine.order(:id).last
    assert_nil line.input_unit_cost_cents
    assert_nil line.input_cost_method
    assert_nil line.input_cost_quality
    assert_nil line.corrected_inventory_value_cents
  end
end
