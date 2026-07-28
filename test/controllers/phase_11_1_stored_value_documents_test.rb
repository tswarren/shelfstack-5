# frozen_string_literal: true

require "test_helper"

class Phase111StoredValueDocumentsTest < ActionDispatch::IntegrationTest
  include PosSetupHelper

  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @cash = tender_types(:cash)
    IdentifierSequence.ensure_defaults!
    _day, @session = pos_open_cash_session(
      store: @store, device: @device, drawer: @drawer, actor: @admin
    )
  end

  test "immediate activity slip and credit voucher after gift card issue" do
    post session_path, params: { username: "admin", password: "password123" }
    account = StoredValue::CreateAccount.call(
      organization: @store.organization, account_type: "gift_card", actor: @admin
    ).account

    open = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddStoredValueLine.call(
      pos_transaction: open, account: account, operation: "issue",
      amount_cents: 2500, actor: @admin
    ).success?
    Pos::AddCashTender.call(
      pos_transaction: open, tender_type: @cash, amount_tendered_cents: 2500, actor: @admin
    )
    post complete_pos_transaction_path(open), params: { completion_idempotency_key: "11-1e-issue" }
    assert_response :redirect
    open.reload
    entry = open.stored_value_entries.find_by!(entry_type: "issued")

    get activity_slip_stored_value_entry_path(entry)
    assert_response :success
    refute_match(/REPRINT/, response.body)
    refute_includes response.body, account.account_number
    assert_match(/GIFT CARD ISSUED/, response.body)
    assert_match(/\*\*\*\* #{Regexp.escape(account.account_number[-4, 4])}/, response.body)
    assert_select ".amount", text: /25\.00/

    get credit_voucher_stored_value_account_path(account)
    assert_response :success
    refute_match(/REPRINT/, response.body)
    assert_includes response.body, account.account_number
    assert_match(/CREDIT VOUCHER/, response.body)
    assert_select ".pos-receipt-barcode-text", text: account.account_number

    before = {
      entry_amount: entry.amount_cents,
      account_balance: account.reload.current_balance_cents,
      entry_count: account.stored_value_entries.count
    }
    get activity_slip_stored_value_entry_path(entry)
    assert_response :success
    assert_equal before[:entry_amount], entry.reload.amount_cents
    assert_equal before[:account_balance], account.reload.current_balance_cents
    assert_equal before[:entry_count], account.stored_value_entries.count
  end

  test "historical reprint requires permission and shows REPRINT" do
    post session_path, params: { username: "admin", password: "password123" }
    account = StoredValue::CreateAccount.call(
      organization: @store.organization, account_type: "gift_card", actor: @admin
    ).account
    entry = StoredValue::PostEntry.call(
      account: account, store: @store, entry_type: "issued", amount_cents: 1200,
      posting_key: "11-1e-hist", actor: @admin
    ).entry

    get activity_slip_reprint_stored_value_entry_path(entry)
    assert_response :success
    assert_match(/REPRINT/, response.body)
    refute_includes response.body, account.account_number

    get credit_voucher_reprint_stored_value_account_path(account)
    assert_response :success
    assert_match(/REPRINT/, response.body)
    assert_includes response.body, account.account_number
  end

  test "immediate slip denied without context; voucher denied when suspended" do
    post session_path, params: { username: "admin", password: "password123" }
    account = StoredValue::CreateAccount.call(
      organization: @store.organization, account_type: "gift_card", actor: @admin
    ).account
    entry = StoredValue::PostEntry.call(
      account: account, store: @store, entry_type: "issued", amount_cents: 900,
      posting_key: "11-1e-nocontext", actor: @admin
    ).entry

    get activity_slip_stored_value_entry_path(entry)
    assert_redirected_to stored_value_account_path(account)
    assert_match(/immediate completion/i, flash[:alert].to_s)

    account.reload.update!(status: "suspended")
    get credit_voucher_reprint_stored_value_account_path(account)
    assert_redirected_to stored_value_account_path(account)
    assert_match(/suspended/i, flash[:alert].to_s)
  end

  test "clerk without print permissions is denied" do
    post session_path, params: { username: "admin", password: "password123" }
    account = StoredValue::CreateAccount.call(
      organization: @store.organization, account_type: "gift_card", actor: @admin
    ).account
    entry = StoredValue::PostEntry.call(
      account: account, store: @store, entry_type: "issued", amount_cents: 700,
      posting_key: "11-1e-deny", actor: @admin
    ).entry

    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get activity_slip_reprint_stored_value_entry_path(entry)
    assert_redirected_to root_path
    assert_match(/not authorized/i, flash[:alert].to_s)

    get credit_voucher_reprint_stored_value_account_path(account)
    assert_redirected_to root_path
    assert_match(/not authorized/i, flash[:alert].to_s)
  end
end
