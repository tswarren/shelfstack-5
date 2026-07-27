# frozen_string_literal: true

require "test_helper"

class Phase11bPickupAndCustomerCreateTest < ActionDispatch::IntegrationTest
  setup do
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @admin = users(:admin)
    @store = stores(:main_street)

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

  test "ready pickup launcher targets overlay and start pickup creates transaction" do
    StockBalance.create!(
      store: @store, product_variant: @variant,
      on_hand: 5, reserved: 0, unavailable: 0,
      inventory_value_cents: 5000, moving_average_cost_cents: 1000, cost_quality: "actual"
    )
    request = ProductRequest.create!(
      store: @store, request_type: "customer_request", product: @variant.product,
      product_variant: @variant, requested_quantity: 2, requested_by_user: @admin,
      customer: customers(:jordan_lee)
    )

    get register_path
    assert_response :success
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_pickup_path,
                  text: "Pickup / Product Request"

    get pos_overlay_pickup_path
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_select "form[action=?]", register_start_pickup_path, count: 0

    get pos_overlay_pickup_path, params: { q: request.id.to_s }
    assert_response :success
    assert_select "form[action=?]", register_start_pickup_path

    assert_difference -> { PosTransaction.count }, 1 do
      post register_start_pickup_path, params: { product_request_id: request.id, quantity: 1 }
    end
    txn = PosTransaction.order(:id).last
    assert_redirected_to pos_transaction_path(txn, intent: "sale")
    line = txn.pos_line_items.pending.last
    assert_equal request.id, line.product_request_id
  end

  test "customer overlay create stays in shell and stages on success" do
    get pos_overlay_customer_path
    assert_response :success
    assert_select "a[href=?][data-turbo-frame=pos_overlay]", pos_overlay_customer_create_path,
                  text: "Create customer"

    get pos_overlay_customer_create_path
    assert_response :success
    assert_select "turbo-frame#pos_overlay dialog"
    assert_select "form[action=?]", register_create_customer_path

    assert_difference -> { Customer.count }, 1 do
      post register_create_customer_path, params: {
        customer: {
          customer_type: "individual",
          first_name: "Avery",
          last_name: "Pickup",
          preferred_contact_method: "none"
        }
      }
    end
    assert_redirected_to register_path
    follow_redirect!
    assert_match(/created and staged/i, flash[:notice].to_s + response.body)

    session = PosSession.open_sessions.order(:id).last
    assert_equal "Avery Pickup", session.staged_customer.display_name
  end
end
