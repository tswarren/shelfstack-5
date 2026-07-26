# frozen_string_literal: true

require "test_helper"

# Gate 11A · Slice 3 — Core Transaction exit journeys.
class Phase11aCoreTransactionTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @admin = users(:admin)
  end

  test "scan build qty remove suspend recall cancel and refresh restore" do
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

    open_inventory(@variant, quantity: 10, unit_cost_cents: 500)

    post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    transaction = PosTransaction.order(:id).last
    assert transaction.open?
    assert_equal 1, transaction.pos_line_items.pending.count
    balance = StockBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 1, balance.reserved

    get pos_transaction_path(transaction)
    assert_response :success
    assert_select "body[data-pos-presentation=transaction]"

    post pos_transaction_pos_line_items_path(transaction), params: { query: @variant.sku, quantity: 1 }
    assert_equal 2, transaction.pos_line_items.pending.count
    assert_equal 2, balance.reload.reserved

    line = transaction.pos_line_items.pending.order(:id).first
    patch pos_transaction_pos_line_item_path(transaction, line), params: { quantity: 3 }
    assert_equal 3, line.reload.quantity
    assert_equal 4, balance.reload.reserved # 3 + second line qty 1

    delete pos_transaction_pos_line_item_path(transaction, line), params: { reason: "test remove" }
    assert_equal "removed", line.reload.status
    assert_equal 1, balance.reload.reserved

    before_refresh = transaction.reload.attributes.slice("status", "updated_at")
    get pos_transaction_path(transaction)
    assert_response :success
    assert_select "body[data-pos-presentation=transaction]"
    assert_equal before_refresh, transaction.reload.attributes.slice("status", "updated_at")

    post suspend_pos_transaction_path(transaction)
    assert_redirected_to register_path
    assert transaction.reload.suspended?
    assert_equal 1, balance.reload.reserved

    get pos_transaction_path(transaction)
    assert_response :success
    assert_select "body[data-pos-presentation=transaction]"

    post recall_pos_transaction_path(transaction)
    assert transaction.reload.open?

    post cancel_pos_transaction_path(transaction), params: { reason: "gate 11a cancel" }
    assert_redirected_to register_path
    assert transaction.reload.cancelled?
    assert_equal 0, balance.reload.reserved

    get pos_transaction_path(transaction)
    assert_redirected_to register_path
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
