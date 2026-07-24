# frozen_string_literal: true

require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "renders the reports dashboard" do
    get reports_path
    assert_response :success
  end

  test "lists open purchase orders with derived receiving state" do
    get open_purchase_orders_report_path
    assert_response :success
    assert_select "body", text: /#{Regexp.escape(purchase_orders(:draft_po).purchase_order_number)}/
  end

  test "lists on-order quantity by product variant" do
    get on_order_report_path
    assert_response :success
    assert_select "body", text: /Illustrated Man/
  end

  test "lists receiving history and partially received orders" do
    get receiving_history_report_path
    assert_response :success
    assert_select "body", text: /#{Regexp.escape(receipts(:draft_receipt).receipt_number)}/
  end

  test "lists customer request coverage" do
    get customer_requests_report_path
    assert_response :success
    assert_select "body", text: /CUST-4471/
  end

  test "lists allocation events" do
    line = purchase_order_lines(:ordered_po_line1)
    request = product_requests(:open_customer_request)
    allocation = Purchasing::CreateAllocation.call(
      purchase_order_line: line, product_request: request, quantity: 1, actor: @admin, store: @store
    ).purchase_order_allocation
    allocation.release!(quantity: 1, reason: "manual_release", actor: @admin)

    get allocation_events_report_path
    assert_response :success
    assert_select "body", text: /Released/
  end

  test "denies clerk without any report permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get reports_path
    assert_redirected_to root_path

    get open_purchase_orders_report_path
    assert_redirected_to root_path

    get receiving_history_report_path
    assert_redirected_to root_path

    get customer_requests_report_path
    assert_redirected_to root_path

    get allocation_events_report_path
    assert_redirected_to root_path
  end

  test "day-only reconciler reaches reports and queue without session reconcile links" do
    role = Role.create!(
      organization: @store.organization,
      code: "day_only_#{SecureRandom.hex(3)}",
      name: "Day Reconciler",
      system_template: false,
      active: true
    )
    RolePermission.create!(role: role, permission: permissions(:reporting_reconcile_business_day))
    user = User.create!(
      username: "dayrecon_#{SecureRandom.hex(3)}",
      user_number: rand(10_000..99_999),
      first_name: "Day",
      last_name: "Only",
      password: "password123",
      active: true,
      default_store: @store
    )
    StoreMembership.create!(user: user, store: @store, role: role, active: true)

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    session = Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: pos_devices(:register_1),
      cash_drawer: cash_drawers(:drawer_1), opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 0).success?
    assert Pos::CloseBusinessDay.call(business_day: day, actor: @admin).success?

    delete session_path
    post session_path, params: { username: user.username, password: "password123" }

    get reports_path
    assert_response :success
    assert_select "a", text: "Open queue"

    get reconciliations_path
    assert_response :success
    assert_select "a", text: "Reconcile", count: 1 # day only
    assert_select "body", text: /Required session reconciliation/
  end
end
