# frozen_string_literal: true

require "test_helper"

class Phase11LineSelectTest < ActionDispatch::IntegrationTest
  setup do
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @admin = users(:admin)
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
    post register_scan_to_start_path, params: { query: @variant.sku, quantity: 1 }
    @transaction = PosTransaction.order(:id).last
    @line = @transaction.pos_line_items.pending.last
  end

  test "line rows expose workspace select controls and selection updates command bar" do
    get pos_transaction_path(@transaction)
    assert_response :success
    assert_select "tr[data-controller='pos-line-row']"
    assert_select "tr[role=button]", count: 0
    assert_select "a.pos-line-select-link[data-turbo-frame=pos_workspace][href=?]",
      pos_transaction_path(@transaction, intent: "sale", selected_line_id: @line.id, focus_target: "line_actions")

    get pos_transaction_path(@transaction, intent: "sale", selected_line_id: @line.id, focus_target: "line_actions")
    assert_response :success
    assert_select "tr.pos-line-selected"
    assert_select ".pos-commands-selected[data-pos-register-target=lineActions]"
    assert_select "a[data-turbo-frame=pos_overlay]", text: "Discount"
    assert_select "a[data-turbo-frame=pos_overlay]", text: "Price"
    assert_select "a[data-turbo-frame=_top][data-turbo-action=advance]", text: /Tender/
    assert_select "a[data-turbo-frame=pos_overlay]", text: "Return"
    assert_select "a[data-turbo-frame=pos_overlay]", text: "Open ring"
  end

  private

  def open_inventory(variant, quantity:, unit_cost_cents:)
    opening = InventoryAdjustment.create!(
      store: stores(:main_street), kind: "opening_inventory", status: "draft",
      inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
    )
    InventoryAdjustmentLine.create!(
      inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
      input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
    )
    assert Inventory::PostAdjustment.call(
      adjustment: opening, actor: @admin, store: stores(:main_street)
    ).success?
  end
end
