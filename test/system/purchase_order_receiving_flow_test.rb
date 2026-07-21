# frozen_string_literal: true

require "application_system_test_case"

# Phase 5g exit-gate coverage: the full vendor -> purchase order -> receipt ->
# on-hand stock path through the browser UI, end to end.
class PurchaseOrderReceivingFlowTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)

    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"
  end

  test "vendor to purchase order to receipt posts accepted quantity into stock" do
    visit new_purchase_order_path
    assert_text "New purchase order"

    select "Ingram Book Company", from: "Vendor"
    within("fieldset.adjustment-line") do
      select "The Illustrated Man — Standard · SKU 2800000000011", from: "Variant"
      select "Standard — INGRAM (9780000000001)", from: "Vendor source"
      fill_in "Ordered quantity", with: "4"
      fill_in "List cost (cents)", with: "1200"
      fill_in "Discount (bps)", with: "4000"
    end
    click_button "Create draft"

    assert_text "Purchase order draft created"
    assert_text "Draft"

    accept_confirm do
      click_button "Place order"
    end
    assert_text "Purchase order placed"
    assert_text "Ordered"

    purchase_order = PurchaseOrder.order(:id).last
    assert_equal "ordered", purchase_order.reload.status

    visit new_receipt_path
    select "Ingram Book Company", from: "Vendor"
    within("fieldset.adjustment-line") do
      select "The Illustrated Man — Standard · SKU 2800000000011 · Quantity", from: "Variant"
      find_field("Purchase order line").find(:option, text: /open 4/).select_option
      fill_in "Delivered quantity", with: "4"
      fill_in "Accepted quantity", with: "4"
      fill_in "Actual unit cost (cents)", with: "700"
      select "Actual", from: "Cost quality"
    end
    click_button "Create draft"

    assert_text "Receipt draft created"
    assert_text "Draft"

    accept_confirm do
      click_button "Post receipt"
    end
    assert_text "Receipt posted"
    assert_text "Posted"

    assert_equal "fully_received", purchase_order.reload.receiving_state

    visit stock_balances_path
    row = find("tr", text: "2800000000011")
    within(row) do
      cells = all("td").map(&:text)
      assert_equal "4", cells[2], "expected on-hand to be 4 after posting the receipt"
      assert_equal "4", cells[5], "expected available to be 4 with no reservation"
    end
  end
end
