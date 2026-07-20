# frozen_string_literal: true

require "test_helper"

class InventoryUnitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists current store's inventory units" do
    unit = Inventory::CreateInventoryUnit.call(
      store: stores(:main_street), product_variant: product_variants(:signed_book_standard),
      actor: users(:admin), acquisition_cost_cents: 1000
    ).inventory_unit

    get inventory_units_path
    assert_response :success
    assert_match unit.unit_identifier, response.body
  end

  test "creates an inventory unit and writes an audit event" do
    variant = product_variants(:signed_book_standard)

    assert_difference("InventoryUnit.count") do
      assert_difference("AdministrativeAuditEvent.count") do
        post inventory_units_path, params: {
          inventory_unit: {
            product_variant_id: variant.id, acquisition_cost_cents: 1200,
            acquisition_source_type: "other", description: "Signed by author"
          }
        }
      end
    end

    unit = InventoryUnit.order(:id).last
    assert_redirected_to inventory_unit_path(unit)
    assert_equal "available", unit.status
    assert_equal "27", unit.unit_identifier[0, 2]
  end

  test "denies clerk without inventory.unit.manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get inventory_units_path
    assert_redirected_to root_path

    get new_inventory_unit_path
    assert_redirected_to root_path
  end

  test "blank variant selection rerenders new with a form object and field error" do
    post inventory_units_path, params: {
      inventory_unit: { product_variant_id: "", description: "No variant" }
    }

    assert_response :unprocessable_entity
    assert_select "form"
    assert_match(/individually tracked variant/i, response.body)
    assert_select "a[href='#inventory_unit_product_variant_id']"
    assert_select "select#inventory_unit_product_variant_id[aria-invalid='true']"
    assert_select "#inventory_unit_product_variant_id_error"
  end

  test "invalid acquisition cost preserves submitted value and field error" do
    variant = product_variants(:signed_book_standard)

    post inventory_units_path, params: {
      inventory_unit: {
        product_variant_id: variant.id,
        acquisition_cost: "twelve",
        description: "Bad cost"
      }
    }

    assert_response :unprocessable_entity
    assert_select "input[name='inventory_unit[description]'][value='Bad cost']"
    assert_select "input#inventory_unit_acquisition_cost[value='twelve'][aria-invalid='true']"
    assert_select "select#inventory_unit_product_variant_id option[selected][value=?]", variant.id.to_s
  end

  test "foreign organization variant id is rejected with a form object" do
    post inventory_units_path, params: {
      inventory_unit: { product_variant_id: 0, description: "Missing" }
    }

    assert_response :unprocessable_entity
    assert_select "form"
    assert_match(/individually tracked variant/i, response.body)
  end
end
