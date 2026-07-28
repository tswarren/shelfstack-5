# frozen_string_literal: true

require "test_helper"

class Phase111ReceiptDocumentsTest < ActionDispatch::IntegrationTest
  include PosSetupHelper

  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)
    pos_open_inventory(store: @store, variant: @variant, quantity: 20, unit_cost_cents: 500, actor: @admin)
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
  end

  test "immediate customer receipt requires server context and never shows REPRINT" do
    post session_path, params: { username: "admin", password: "password123" }

    # Complete via controller path to plant immediate context.
    open = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: open, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: open).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: open, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    post complete_pos_transaction_path(open), params: { completion_idempotency_key: "11-1a-ctx" }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    open.reload
    assert_predicate open, :completed?

    get customer_receipt_pos_transaction_path(open)
    assert_response :success
    refute_match(/REPRINT/, response.body)
    assert_select ".pos-receipt-meta", text: /Receipt/
    assert_select ".pos-receipt-barcode-text", text: open.receipt_number

    get register_path
    assert_response :success

    get customer_receipt_pos_transaction_path(open)
    assert_redirected_to pos_transaction_path(open)
    assert_match(/immediate completion/i, flash[:alert].to_s)

    get customer_receipt_reprint_pos_transaction_path(open)
    assert_response :success
    assert_match(/REPRINT/, response.body)
    assert_match(/Reprint/, response.body)
    refute_match(/\?reprint=false/, response.body)
  end

  test "query params cannot forge original or suppress reprint" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11-1a-forge"
    )

    get customer_receipt_reprint_pos_transaction_path(txn, reprint: false)
    assert_response :success
    assert_match(/REPRINT/, response.body)

    get customer_receipt_pos_transaction_path(txn, reprint: false)
    assert_redirected_to pos_transaction_path(txn)
  end

  test "gift receipt omits commercial content and customer identity" do
    post session_path, params: { username: "admin", password: "password123" }
    customer = customers(:jordan_lee)
    open = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    open.update_columns(customer_id: customer.id)
    Pos::AddLine.call(pos_transaction: open, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: open).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: open, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    post complete_pos_transaction_path(open), params: { completion_idempotency_key: "11-1b-gift" }
    open.reload

    get gift_receipt_pos_transaction_path(open)
    assert_response :success
    assert_match(/GIFT RECEIPT/, response.body)
    assert_match(/Receipt #{Regexp.escape(open.receipt_number)}/, response.body)
    refute_match(/Merchandise|Tenders|\bTax\b|Discount|Customer \*\*\*\*/i, response.body)
    refute_match(/#{Regexp.escape(customer.display_name)}/, response.body)
    refute_match(/#{Regexp.escape(customer.customer_number)}/, response.body)
    refute_select ".pos-receipt-item"
  end

  test "customer receipt masks customer number" do
    post session_path, params: { username: "admin", password: "password123" }
    customer = customers(:jordan_lee)
    open = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    open.update_columns(customer_id: customer.id)
    Pos::AddLine.call(pos_transaction: open, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: open).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: open, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    post complete_pos_transaction_path(open), params: { completion_idempotency_key: "11-1b-mask" }
    open.reload

    get customer_receipt_pos_transaction_path(open)
    assert_response :success
    assert_match(/Customer \*\*\*\* #{Regexp.escape(customer.customer_number[-4, 4])}/, response.body)
    refute_match(/#{Regexp.escape(customer.display_name)}/, response.body)
    refute_match(/#{Regexp.escape(customer.customer_number)}\b/, response.body)
  end

  test "reprint denied without pos.receipt.reprint and immediate denied without context" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11-1a-deny"
    )
    before = txn.reload.attributes.slice("status", "receipt_number", "net_total_cents")

    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get customer_receipt_reprint_pos_transaction_path(txn)
    assert_redirected_to root_path
    assert_match(/not authorized/i, flash[:alert].to_s)

    get customer_receipt_pos_transaction_path(txn)
    assert_redirected_to pos_transaction_path(txn)
    assert_equal before, txn.reload.attributes.slice("status", "receipt_number", "net_total_cents")
  end

  test "receipt GET does not mutate completed transaction" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11-1a-nomut"
    )
    before = txn.reload.attributes.slice("status", "receipt_number", "net_total_cents", "completed_at")

    get customer_receipt_reprint_pos_transaction_path(txn)
    assert_response :success
    assert_equal before, txn.reload.attributes.slice("status", "receipt_number", "net_total_cents", "completed_at")
  end

  test "store header change affects later reprint without changing amounts" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11-1d-header"
    )
    net_before = txn.net_total_cents

    @store.update!(receipt_header: "Seasonal header #{SecureRandom.hex(4)}")
    get customer_receipt_reprint_pos_transaction_path(txn)
    assert_response :success
    assert_match(/Seasonal header/, response.body)
    assert_equal net_before, txn.reload.net_total_cents
  end

  test "post-void receipt and VOIDED original reprint" do
    post session_path, params: { username: "admin", password: "password123" }
    original, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11-1c-sale"
    )

    result = pos_post_void!(
      original: original, actor: @admin, reason: "cashier error",
      pos_session: @session, key: "11-1c-void"
    )
    assert result.success?, result.error
    reversing = result.pos_transaction

    # Plant immediate context for reversing txn via another completion-shaped store.
    # Historical reprint path is enough for content assertions.
    get post_void_receipt_reprint_pos_transaction_path(reversing)
    assert_response :success
    assert_match(/POST-VOID/, response.body)
    assert_match(/REPRINT/, response.body)
    assert_select ".pos-receipt-barcode-text", text: reversing.receipt_number
    assert_match(/Original receipt/, response.body)
    assert_match(/#{Regexp.escape(original.receipt_number)}/, response.body)
    # Line-level tax rows store magnitudes; receipt display must sign returns negative.
    assert_operator reversing.tax_total_cents, :<, 0
    assert_select ".pos-receipt-totals .amount", text: /-\$#{Regexp.escape(format("%.2f", reversing.tax_total_cents.abs / 100.0))}/
    assert_select ".pos-receipt-totals dt", text: /Tax .+ @ /
    assert_select ".pos-receipt-tax-legend", text: / -/

    get gift_receipt_reprint_pos_transaction_path(reversing)
    assert_redirected_to pos_transaction_path(reversing)

    get customer_receipt_reprint_pos_transaction_path(original)
    assert_response :success
    assert_match(/VOIDED/, response.body)
    assert_match(/Reversed by receipt/, response.body)
    assert_match(/#{Regexp.escape(reversing.receipt_number)}/, response.body)
    assert_select ".pos-receipt-barcode-text", text: original.receipt_number

    get gift_receipt_reprint_pos_transaction_path(original)
    assert_response :success
    assert_match(/GIFT RECEIPT/, response.body)
    assert_match(/VOIDED/, response.body)
  end

  test "barcode payload equals receipt number" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11-1a-barcode"
    )
    barcode = Pos::ReceiptBarcode.call(receipt_number: txn.receipt_number)
    assert_nil barcode.error
    assert_equal txn.receipt_number, barcode.payload
    assert_includes barcode.svg, "<svg"
  end

  test "customer receipt shows tax markers totals format and legend" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11-1-tax-layout"
    )

    get customer_receipt_reprint_pos_transaction_path(txn)
    assert_response :success
    assert_select ".pos-receipt-tax-markers", text: /G/
    assert_select ".pos-receipt-totals dt", text: /Tax G \(\$.+ @ 13\.000%\)/
    assert_select ".pos-receipt-totals", text: /Total Merchandise/
    assert_select ".pos-receipt-totals", text: /Total Due/
    assert_select ".pos-receipt-meta", text: /Receipt/
    assert_select ".pos-receipt-tax-legend", text: /G - /
    assert_select ".pos-receipt-tax-legend", text: /GST/
    assert_select ".pos-receipt-item-counts", text: /Items Sold/
  end

  test "gift receipt shows fill-in lines and gift title after meta" do
    post session_path, params: { username: "admin", password: "password123" }
    txn, = pos_complete_cash_sale(
      session: @session, variant: @variant, quantity: 1, actor: @admin,
      cash: @cash, key: "11-1-gift-layout"
    )

    get gift_receipt_reprint_pos_transaction_path(txn)
    assert_response :success
    assert_select ".pos-receipt-banner", text: /GIFT RECEIPT/
    assert_select ".pos-gift-fill-ins", text: /To:/
    assert_select ".pos-gift-fill-ins", text: /From:/
    assert_select ".pos-receipt-barcode-text", text: txn.receipt_number
    assert_select ".pos-receipt-lines", count: 0
    assert_select ".pos-receipt-totals", count: 0
  end

  test "customer receipt masks stored-value account numbers and never prints full number" do
    post session_path, params: { username: "admin", password: "password123" }
    IdentifierSequence.ensure_defaults!
    account = StoredValue::CreateAccount.call(
      organization: @store.organization, account_type: "gift_card", actor: @admin
    ).account

    open = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    line_result = Pos::AddStoredValueLine.call(
      pos_transaction: open, account: account, operation: "issue",
      amount_cents: 2500, actor: @admin
    )
    assert line_result.success?, line_result.error
    # Legacy completed lines may still embed the full number in description_snapshot.
    line_result.pos_line_item.update_columns(
      description_snapshot: "Issue gift card #{account.account_number}"
    )
    Pos::AddCashTender.call(
      pos_transaction: open, tender_type: @cash, amount_tendered_cents: 2500, actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: open, pos_session: @session, actor: @admin,
      completion_idempotency_key: "11-1-sv-mask"
    ).success?

    get customer_receipt_reprint_pos_transaction_path(open.reload)
    assert_response :success
    refute_includes response.body, account.account_number
    assert_select ".pos-receipt-item__description", text: "Gift Card Sale"
    assert_select ".pos-receipt-item__identifier", text: /#{Regexp.escape(account.account_number[-4, 4])}/
    assert_select ".pos-receipt-item__identifier", text: /\*{4}/
  end
end
