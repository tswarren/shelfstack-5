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

  test "ready supporting actions target overlay frame and leave-POS uses _top" do
    get register_path
    assert_response :success
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_customer_path, text: "Customer"
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_receipt_lookup_path, text: "Receipt lookup"
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_open_ring_path, text: "Open Ring"
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_cash_movement_path, text: "Cash Movement"
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_no_sale_path, text: "No Sale"
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_pickup_path, text: "Pickup / Product Request"
  end

  test "overlay endpoints render dialog fragments" do
    get pos_overlay_customer_path
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"

    get pos_overlay_open_ring_path
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"

    get pos_overlay_cash_movement_path
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
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

  test "failed cash movement returns to register with alert" do
    session = PosSession.open_sessions.order(:id).last
    type = CashMovementType.find_by!(organization: stores(:main_street).organization, code: "additional_float")

    assert_no_difference "PosCashMovement.count" do
      post pos_session_pos_cash_movements_path(session), params: {
        cash_movement_type_id: type.id,
        amount_cents: "0.00",
        reason: "zero"
      }
    end
    assert_redirected_to register_path
    follow_redirect!
    assert_match(/amount must be positive/i, response.body)
  end
end
