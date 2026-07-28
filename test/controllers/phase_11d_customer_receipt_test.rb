# frozen_string_literal: true

require "test_helper"

# Gate 11D residual coverage retained; Phase 11.1 owns original/reprint authority.
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

  test "customer receipt is browser printable HTML from completed snapshots via reprint" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11d-receipt"
    )

    get customer_receipt_reprint_pos_transaction_path(txn)
    assert_response :success
    assert_select ".pos-receipt-barcode-text", text: txn.receipt_number
    assert_select ".pos-receipt-meta", text: /Receipt/
    assert_match(/\b#{txn.completed_at.year}\b/, response.body)
    assert_match(/Browser print path only/, response.body)
    assert_select "button", text: "Print again"
    assert_match(/REPRINT/, response.body)

    status_before = txn.reload.status
    get customer_receipt_reprint_pos_transaction_path(txn)
    assert_response :success
    assert_equal status_before, txn.reload.status
    assert_equal "completed", txn.status
  end

  test "customer receipt shows discount adjustments and line net for discounted items" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    added = Pos::AddLine.call(
      pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin
    )
    assert added.success?
    line = added.pos_line_item
    extended = line.extended_price_cents
    discount_amount = 200
    applied = Pos::ApplyDiscount.call(
      pos_transaction: txn, scope: "line", pos_line_item: line,
      method: "fixed_amount", amount_cents: discount_amount, actor: @admin
    )
    assert applied.success?

    net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    complete = Pos::CompleteTransaction.call(
      pos_transaction: txn, pos_session: @session, actor: @admin,
      completion_idempotency_key: "11d-receipt-discount"
    )
    assert complete.success?

    get customer_receipt_reprint_pos_transaction_path(txn.reload)
    assert_response :success
    assert_select ".pos-receipt-item__row--adjustment", text: /Discount/
    assert_select ".pos-receipt-item__row--net", text: /Net/
    assert_match(/#{Regexp.escape(format("%.2f", (extended - discount_amount) / 100.0))}/, response.body)
    assert_select ".pos-receipt-totals", text: /Total Merchandise/
    assert_select ".pos-receipt-totals", text: /Subtotal/
    assert_select ".pos-receipt-savings", text: /Total Savings:.*2\.00/
  end

  test "customer receipt is unavailable for open transactions" do
    post session_path, params: { username: "admin", password: "password123" }
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    get customer_receipt_reprint_pos_transaction_path(txn)
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

  test "receipt lookup can begin linked return directly" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11d-lookup-return"
    )

    post register_lookup_receipt_path, params: {
      receipt_number: txn.receipt_number,
      start_linked_return: "true"
    }
    assert_response :redirect
    follow_redirect!
    assert_match(/loaded for return/i, flash[:notice].to_s)
    open_txn = PosTransaction.open_transactions.find_by(active_pos_session: @session)
    assert open_txn.present?
    assert_equal txn.id, session[:pos_return_lookup]["original_transaction_id"]
  end

  test "customer receipt keeps snapshotted description after catalog rename" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, line, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11d-snapshot"
    )
    original_name = line.description_snapshot
    assert_predicate original_name, :present?

    @variant.product.update!(name: "Renamed After Completion")
    get customer_receipt_reprint_pos_transaction_path(txn)
    assert_response :success
    assert_select ".pos-receipt-item__description", text: /#{Regexp.escape(original_name)}/
    refute_match(/Renamed After Completion/, response.body)
  end

  test "completed Receipt presentation uses dedicated composition" do
    post session_path, params: { username: "admin", password: "password123" }
    open = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: open, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: open).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: open, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    post complete_pos_transaction_path(open), params: { completion_idempotency_key: "11d-receipt-ui" }
    follow_redirect!

    assert_response :success
    assert_select ".pos-shell[data-pos-presentation=receipt]"
    assert_select "section[aria-label='Completed transaction']", text: /Transaction complete/
    assert_select "a", text: "Next transaction"
    assert_select "a", text: "Print Receipt"
    assert_select "a", text: "Print Gift Receipt"
  end
end
