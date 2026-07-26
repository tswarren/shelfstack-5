# frozen_string_literal: true

require "test_helper"

class Phase11bProductLookupTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @admin = users(:admin)
  end

  test "ready product lookup add creates transaction atomically" do
    post session_path, params: { username: "admin", password: "password123" }
    post business_days_path, params: { business_day: { reporting_date: Date.current } }
    business_day = BusinessDay.order(:id).last
    post pos_sessions_path, params: {
      pos_session: {
        business_day_id: business_day.id,
        pos_device_id: @device.id,
        cash_drawer_id: @drawer.id,
        opening_cash_cents: 0
      }
    }
    open_inventory(@variant, quantity: 3, unit_cost_cents: 500)

    get register_path
    assert_response :success
    assert_match(/Product lookup/, response.body)

    assert_difference "PosTransaction.count", 1 do
      post register_scan_to_start_path, params: { product_variant_id: @variant.id, quantity: 2 }
    end
    transaction = PosTransaction.order(:id).last
    assert_redirected_to pos_transaction_path(transaction)
    assert_equal 1, transaction.pos_line_items.pending.count
    assert_equal 2, transaction.pos_line_items.pending.first.quantity
  end

  test "transaction product lookup add uses existing transaction" do
    post session_path, params: { username: "admin", password: "password123" }
    post business_days_path, params: { business_day: { reporting_date: Date.current } }
    business_day = BusinessDay.order(:id).last
    post pos_sessions_path, params: {
      pos_session: {
        business_day_id: business_day.id,
        pos_device_id: @device.id,
        cash_drawer_id: @drawer.id,
        opening_cash_cents: 0
      }
    }
    open_inventory(@variant, quantity: 5, unit_cost_cents: 500)
    post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    transaction = PosTransaction.order(:id).last

    get pos_transaction_path(transaction)
    assert_response :success
    assert_match(/Product lookup/, response.body)

    assert_no_difference "PosTransaction.count" do
      post pos_transaction_pos_line_items_path(transaction), params: {
        product_variant_id: @variant.id, quantity: 1, intent: "sale"
      }
    end
    assert_equal 2, transaction.pos_line_items.pending.count
  end

  test "cashiers with pos.access can search product variants for lookup" do
    assert Catalog::SearchRecords.authorized?(
      user: @admin, store: @store, record_type: "product_variant"
    )
  end

  private

  def open_inventory(variant, quantity:, unit_cost_cents:)
    opening = InventoryAdjustment.create!(
      store: @store, kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
      input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
    )
    assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
  end
end
