# frozen_string_literal: true

require "application_system_test_case"

class PosRefundUiSystemTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @admin = users(:admin)
    @cash = tender_types(:cash)
    @sv = tender_types(:stored_value)
    @card = tender_types(:card_standalone)
    IdentifierSequence.ensure_defaults!
    pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)

    @account = StoredValue::CreateAccount.call(
      organization: @store.organization, account_type: "gift_card", actor: @admin,
      alternate_identifier: "ui-refund-alt-#{SecureRandom.hex(2)}"
    ).account
    StoredValue::PostEntry.call(
      account: @account, store: @store, entry_type: "issued", amount_cents: 50_000,
      posting_key: "ui-refund-seed-#{SecureRandom.hex(3)}", actor: @admin
    )
  end

  test "restore original stored value then cash through register refund forms" do
    sign_in_and_open_session!
    sale_line, sv_tender, cash_tender = complete_split_sale_ui_setup!

    ret = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
    ).success?

    visit pos_transaction_path(ret)
    due = -Pos::RecalculateTransaction.call(pos_transaction: ret).net_total_cents
    sv_amount = sv_tender.amount_cents
    cash_amount = due - sv_amount
    assert cash_amount.positive?

    within_panel("Stored-value refund") do
      select_option_value("original_pos_tender_id", sv_tender.id)
      find("#sv_refund_amount_cents").set(format("%.2f", sv_amount / 100.0))
      uncheck "create_store_credit" if page.has_field?("create_store_credit", wait: 1)
      click_button "Record stored-value refund"
    end
    assert_selector ".flash, [role='status'], .notice", text: /Tender recorded/i
    assert_equal 1, ret.reload.pos_tenders.where(direction: "refunded").count

    visit pos_transaction_path(ret)
    within_panel("Cash refund") do
      select_option_value("original_pos_tender_id", cash_tender.id)
      find("#refund_amount_cents").set(format("%.2f", cash_amount / 100.0))
      click_button "Add cash refund"
    end
    assert_selector ".flash, [role='status'], .notice", text: /Tender recorded/i
    assert_equal 2, ret.reload.pos_tenders.where(direction: "refunded").count

    click_button "Complete transaction"
    assert_text(/completed/i)
    assert ret.reload.completed?
  end

  test "cash exception without approver credentials is blocked" do
    sign_in_and_open_session!
    sale_line, = complete_cash_sale!

    ret = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
    ).success?

    visit pos_transaction_path(ret)
    due = -Pos::RecalculateTransaction.call(pos_transaction: ret).net_total_cents

    within_panel("Cash refund") do
      select "Select original… (or exception below)", from: "Original cash tender"
      fill_in "refund_amount_cents", with: format("%.2f", due / 100.0)
      click_button "Add cash refund"
    end
    assert_text(/restore remaining original|exception approval/i)
    assert_equal 0, ret.pos_tenders.where(direction: "refunded").count
  end

  test "card refund prepare and record links original tender" do
    sign_in_and_open_session!
    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCardTender.call(
      pos_transaction: sale, tender_type: @card, amount_cents: net,
      authorization_code: "SALE-UI", actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ui-card-sale"
    ).success?
    sale_line = sale.pos_line_items.where(status: "completed").first
    card_tender = sale.pos_tenders.where(status: "completed").first

    ret = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
    ).success?

    visit pos_transaction_path(ret)
    due = -Pos::RecalculateTransaction.call(pos_transaction: ret).net_total_cents

    within_panel("Card refund") do
      select_option_value("original_pos_tender_id", card_tender.id)
      fill_in "card_refund_prepare_amount_cents", with: format("%.2f", due / 100.0)
      click_button "Prepare card refund plan"
    end
    assert_text(/Plan ready|process the terminal/i)

    within_panel("Card refund") do
      assert_no_selector "input[name='amount_cents']"
      fill_in "Refund authorization code", with: "RFND-UI-1"
      click_button "Record authorized card refund"
    end
    assert_selector ".flash, [role='status'], .notice", text: /Tender recorded/i
    refund = ret.pos_tenders.where(direction: "refunded").last
    assert_equal card_tender.id, refund.original_pos_tender_id
    refute refund.requires_reconciliation?
    assert PosCardRefundPreparation.find_by(pos_tender_id: refund.id).recorded_tender?
  end

  test "abandon stale card refund preparation unlocks transaction" do
    sign_in_and_open_session!
    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCardTender.call(
      pos_transaction: sale, tender_type: @card, amount_cents: net,
      authorization_code: "SALE-UI-2", actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ui-card-sale-2"
    ).success?
    sale_line = sale.pos_line_items.where(status: "completed").first
    card_tender = sale.pos_tenders.where(status: "completed").first

    ret = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
    ).success?

    visit pos_transaction_path(ret)
    due = -Pos::RecalculateTransaction.call(pos_transaction: ret).net_total_cents
    within_panel("Card refund") do
      select_option_value("original_pos_tender_id", card_tender.id)
      fill_in "card_refund_prepare_amount_cents", with: format("%.2f", due / 100.0)
      click_button "Prepare card refund plan"
    end
    assert_button "Abandon preparation"
    # Turbo replaces the Card refund panel after prepare; click outside a stale within().
    accept_confirm(/Abandon only if/) { click_button "Abandon preparation" }
    assert_text(/abandoned/i)
    refute ret.reload.card_refund_preparation_outstanding?
  end

  test "invalid stored-value account input is rejected on redeem" do
    sign_in_and_open_session!
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)

    visit pos_transaction_path(txn)
    within_panel("Stored-value tender") do
      fill_in "Account number", with: "0000000000000"
      fill_in "sv_tender_amount_cents", with: "1.00"
      click_button "Redeem stored value"
    end
    assert_text(/required|not found|account/i)
  end

  test "resolve reconciliation tender via validated_and_accepted" do
    sign_in_and_open_session!
    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCardTender.call(
      pos_transaction: sale, tender_type: @card, amount_cents: net,
      authorization_code: "SALE-RECON-UI", actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ui-recon-sale"
    ).success?
    sale_line = sale.pos_line_items.where(status: "completed").first
    card_tender = sale.pos_tenders.where(status: "completed").first

    ret = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
    ).success?
    due = -Pos::RecalculateTransaction.call(pos_transaction: ret).net_total_cents
    prep = Pos::PrepareCardRefund.call(
      pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
      original_pos_tender: card_tender
    ).preparation
    prep.update_columns(expires_at: 1.hour.ago)
    recorded = Pos::AddCardRefundTender.call(
      preparation: prep, authorization_code: "RFND-RECON-UI", actor: @admin
    )
    assert recorded.requires_reconciliation

    visit pos_transaction_path(ret)
    within_panel("Resolve card refund reconciliation") do
      select "Validated and accepted", from: "Outcome"
      fill_in "Reason", with: "terminal confirmed"
      fill_in "Exception approver (for accepted outcomes)", with: "admin"
      fill_in "Approver PIN", with: "1234"
      click_button "Resolve reconciliation"
    end
    assert_text(/reconciliation resolved/i)
    refute recorded.pos_tender.reload.requires_reconciliation?
  end

  test "resolve orphan via external void on queue page" do
    sign_in_and_open_session!
    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCardTender.call(
      pos_transaction: sale, tender_type: @card, amount_cents: net,
      authorization_code: "SALE-ORPH-UI", actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ui-orph-sale"
    ).success?
    sale_line = sale.pos_line_items.where(status: "completed").first
    card_tender = sale.pos_tenders.where(status: "completed").first

    ret = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
    ).success?
    due = -Pos::RecalculateTransaction.call(pos_transaction: ret).net_total_cents
    prep = Pos::PrepareCardRefund.call(
      pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
      original_pos_tender: card_tender
    ).preparation
    assert Pos::AbandonCardRefundPreparation.call(preparation: prep, actor: @admin).success?
    assert Pos::AddCardRefundTender.call(
      preparation: prep.reload, authorization_code: "ORPH-UI-1", actor: @admin
    ).success?

    visit pos_card_refund_orphans_path
    assert_text "ORPH-UI-1"
    within("tr", text: "ORPH-UI-1") do
      select "External void confirmed", from: "resolution_kind"
      fill_in "reason", with: "voided at terminal"
      fill_in "external_void_reference", with: "VOID-UI-1"
      click_button "Resolve"
    end
    assert_text(/resolved/i)
    refute PosCardRefundPreparation.unresolved_orphans.exists?(id: prep.id)
  end

  test "stored value redeem resolves canonical and alternate identifiers" do
    sign_in_and_open_session!
    txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
    visit pos_transaction_path(txn)

    within_panel("Stored-value tender") do
      fill_in "Account number", with: @account.account_number
      fill_in "sv_tender_amount_cents", with: "1.00"
      click_button "Redeem stored value"
    end
    assert_selector ".flash, [role='status'], .notice", text: /Tender recorded|recorded/i

    txn2 = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: txn2, product_variant: @variant, quantity: 1, actor: @admin)
    visit pos_transaction_path(txn2)
    within_panel("Stored-value tender") do
      fill_in "Account number", with: @account.alternate_identifier
      fill_in "sv_tender_amount_cents", with: "1.00"
      click_button "Redeem stored value"
    end
    assert_selector ".flash, [role='status'], .notice", text: /Tender recorded|recorded/i
  end

  test "store recovery form records late authorization as orphan" do
    sign_in_and_open_session!
    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCardTender.call(
      pos_transaction: sale, tender_type: @card, amount_cents: net,
      authorization_code: "SALE-LATE", actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ui-late-sale"
    ).success?
    sale_line = sale.pos_line_items.where(status: "completed").first
    card_tender = sale.pos_tenders.where(status: "completed").first

    ret = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
    ).success?
    due = -Pos::RecalculateTransaction.call(pos_transaction: ret).net_total_cents
    prep = Pos::PrepareCardRefund.call(
      pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
      original_pos_tender: card_tender
    ).preparation
    assert Pos::AbandonCardRefundPreparation.call(preparation: prep, actor: @admin).success?

    visit pos_card_refund_orphans_path
    assert_text(/Record late authorization/i)
    fill_in "Preparation ID", with: prep.id
    fill_in "Authorization code", with: "LATE-UI-1"
    click_button "Record authorization"
    assert_text(/orphan/i)

    prep.reload
    assert prep.recorded_orphan?
    assert_equal "LATE-UI-1", prep.authorization_code
    assert_text prep.authorization_code
  end

  private

  def within_panel(summary_text, &block)
    # Turbo stream updates can replace the details node between find and use.
    attempts = 0
    begin
      attempts += 1
      details = find("details", text: /#{Regexp.escape(summary_text)}/i, match: :first)
      page.execute_script("arguments[0].open = true", details.native)
      within(details, &block)
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      raise if attempts >= 3

      retry
    end
  end

  def select_option_value(name, value)
    find("select[name='#{name}']").find("option[value='#{value}']").select_option
  end

  def sign_in_and_open_session!
    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"

    day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
  end

  def complete_split_sale_ui_setup!
    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    sv_pay = net / 2
    cash_pay = net - sv_pay
    assert Pos::AddStoredValueTender.call(
      pos_transaction: sale, tender_type: @sv, account: @account,
      amount_cents: sv_pay, actor: @admin
    ).success?
    Pos::AddCashTender.call(
      pos_transaction: sale, tender_type: @cash, amount_tendered_cents: cash_pay, actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ui-split-sale"
    ).success?
    [
      sale.pos_line_items.where(status: "completed").first,
      sale.pos_tenders.joins(:tender_type).find_by!(status: "completed", tender_types: { tender_category: "stored_value" }),
      sale.pos_tenders.joins(:tender_type).find_by!(status: "completed", tender_types: { tender_category: "cash" })
    ]
  end

  def complete_cash_sale!
    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCashTender.call(
      pos_transaction: sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ui-cash-sale"
    ).success?
    [ sale.pos_line_items.where(status: "completed").first ]
  end
end
