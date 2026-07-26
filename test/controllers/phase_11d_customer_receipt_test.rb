# frozen_string_literal: true

require "test_helper"

class Phase11dCustomerReceiptTest < ActionDispatch::IntegrationTest
  include PosSetupHelper

  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)
    pos_open_inventory(store: @store, variant: @variant, quantity: 5, unit_cost_cents: 500, actor: @admin)
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
  end

  test "customer receipt is browser printable HTML from completed snapshots" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11d-receipt"
    )

    get customer_receipt_pos_transaction_path(txn)
    assert_response :success
    assert_match(/Receipt #{Regexp.escape(txn.receipt_number)}/, response.body)
    assert_match(/Browser print path only/, response.body)
    assert_select "button", text: "Print"
    refute_match(/REPRINT/, response.body)

    status_before = txn.reload.status
    get customer_receipt_pos_transaction_path(txn, reprint: true)
    assert_response :success
    assert_match(/REPRINT/, response.body)
    assert_match(/Receipt #{Regexp.escape(txn.receipt_number)}/, response.body)
    assert_equal status_before, txn.reload.status
    assert_equal "completed", txn.status
  end

  test "customer receipt is unavailable for open transactions" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    get customer_receipt_pos_transaction_path(txn)
    assert_redirected_to pos_transaction_path(txn)
  end

  test "receipt lookup still finds completed receipt without mutation" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11d-lookup"
    )
    before = txn.reload.attributes.slice("status", "receipt_number", "net_total_cents")

    post register_lookup_receipt_path, params: { receipt_number: txn.receipt_number }
    assert_redirected_to pos_transaction_path(txn)
    assert_equal before, txn.reload.attributes.slice("status", "receipt_number", "net_total_cents")
  end
end
