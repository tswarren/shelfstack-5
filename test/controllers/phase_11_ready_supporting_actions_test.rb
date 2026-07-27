# frozen_string_literal: true

require "test_helper"

class Phase11ReadySupportingActionsTest < ActionDispatch::IntegrationTest
  setup do
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @department = departments(:books_new)
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
  end

  test "ready supporting actions open named overlays and product requests leave the frame" do
    get register_path
    assert_response :success
    assert_select "button[data-pos-overlay-id-param='pos-customer']", text: "Customer"
    assert_select "button[data-pos-overlay-id-param='pos-receipt-lookup']", text: "Receipt lookup"
    assert_select "button[data-pos-overlay-id-param='pos-open-ring']", text: "Open Ring"
    assert_select "button[data-pos-overlay-id-param='pos-cash-movement']", text: "Cash Movement"
    assert_select "button[data-pos-overlay-id-param='pos-no-sale']", text: "No Sale"
    assert_select "dialog#pos-customer"
    assert_select "dialog#pos-receipt-lookup"
    assert_select "dialog#pos-open-ring"
    assert_select "dialog#pos-cash-movement"
    assert_select "dialog#pos-no-sale"
    assert_select "a[href=?][data-turbo-frame=_top]", product_requests_path, text: "Pickup / Product Request"
  end

  test "failed cash movement returns to register with overlay reopen hint" do
    session = PosSession.open_sessions.order(:id).last
    type = CashMovementType.find_by!(organization: stores(:main_street).organization, code: "additional_float")

    assert_no_difference "PosCashMovement.count" do
      post pos_session_pos_cash_movements_path(session), params: {
        cash_movement_type_id: type.id,
        amount_cents: "0.00",
        reason: "zero"
      }
    end
    assert_redirected_to register_path(overlay: "pos-cash-movement")
    follow_redirect!
    assert_select "[data-pos-overlay-open-on-connect-value='pos-cash-movement']"
    assert_match(/amount must be positive/i, response.body)
  end

  test "start open ring from ready creates first-valid-work transaction" do
    assert_difference -> { PosTransaction.count }, 1 do
      post register_start_open_ring_path, params: {
        department_id: @department.id,
        unit_price_cents: "12.50",
        quantity: 1,
        description: "Misc book"
      }
    end
    txn = PosTransaction.order(:id).last
    assert_redirected_to pos_transaction_path(txn, intent: "open_ring")
    assert_equal 1, txn.pos_line_items.pending.count
    assert_equal "open_ring", txn.pos_line_items.pending.last.line_kind
  end
end
