# frozen_string_literal: true

require "application_system_test_case"

# Phase 6.5: Ready scan-to-start → cash tender → complete → Next → Ready.
class PosCashierWorkspaceSystemTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @admin = users(:admin)
  end

  test "ready scan to start cash complete next returns to ready" do
    open_inventory(@variant, quantity: 5, unit_cost_cents: 500)

    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    )

    visit register_path
    assert_text "Register ready"
    assert_button "Scan to start"

    before_count = PosTransaction.count
    within("section[aria-label='Next action']") do
      fill_in "Scan or search", with: @variant.sku
      click_button "Scan to start"
    end

    assert_text(/Line added|available quantity/i, wait: 5)
    assert_equal before_count + 1, PosTransaction.count
    transaction = PosTransaction.order(:id).last
    assert_current_path pos_transaction_path(transaction)
    assert_text "State:"
    assert_text "Transaction"

    click_link "Tender", href: /\/tender/
    assert_text "State:"
    assert_text "Tender"

    net = transaction.reload.pos_line_items.pending.sum { |l|
      l.extended_price_cents.to_i - l.discount_amount_cents.to_i + l.tax_amount_cents.to_i
    }
    fill_in "Amount tendered", with: format("%.2f", net / 100.0)
    click_button "Add cash tender"
    assert_text "Tender recorded"

    click_button "Complete transaction"
    assert_text(/Transaction complete|Receipt/i, wait: 5)
    assert transaction.reload.completed?
    assert_link "Next transaction"

    click_link "Next transaction"
    assert_current_path register_path
    assert_text "Register ready"
    assert_no_text "Resume transaction"
    assert_equal 0, PosTransaction.open_transactions.where(active_pos_session: PosSession.open_sessions.last).count
  end

  test "browser back after complete does not expose editable controls" do
    open_inventory(@variant, quantity: 5, unit_cost_cents: 500)

    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    )

    visit register_path
    within("section[aria-label='Next action']") do
      fill_in "Scan or search", with: @variant.sku
      click_button "Scan to start"
    end
    assert_text(/Line added|available quantity/i, wait: 5)
    transaction = PosTransaction.order(:id).last

    click_link "Tender", href: /\/tender/
    net = Pos::RecalculateTransaction.call(pos_transaction: transaction).net_total_cents
    fill_in "Amount tendered", with: format("%.2f", net / 100.0)
    click_button "Add cash tender"
    assert_text "Tender recorded"
    click_button "Complete transaction"
    assert_text(/Transaction complete|Receipt/i, wait: 5)

    visit register_path
    assert_text "Register ready"
    page.go_back

    assert_text "Transaction complete", wait: 5
    assert_no_button "Add line"
    assert_no_button "Complete transaction"
    assert_no_field "Scan or search"
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
