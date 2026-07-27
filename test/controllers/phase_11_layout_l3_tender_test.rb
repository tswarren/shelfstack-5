# frozen_string_literal: true

require "test_helper"

class Phase11LayoutL3TenderTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    post session_path, params: { username: "admin", password: "password123" }
    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: departments(:books_new),
      unit_price_cents: 500, actor: @admin
    )
  end

  test "tender workspace exposes one active form and method selectors" do
    get tender_pos_transaction_path(@transaction)
    assert_response :success
    assert_select ".pos-shell[data-pos-presentation=tender]"
    assert_select ".pos-tender-workspace"
    assert_select "div[aria-label='Select tender method'] a", minimum: 1
    assert_select "form#active_tender_form", count: 1
    assert_select "details > summary", text: /Cash tender/i, count: 0
    assert_select "button[type=submit][form=active_tender_form]", minimum: 1
    assert_select "a[href=?]", tender_pos_transaction_path(@transaction, tender_method: "card", intent: "sale")
  end

  test "selected tender method survives on the dedicated tender route" do
    get tender_pos_transaction_path(@transaction, tender_method: "card")
    assert_response :success
    assert_select "a[aria-current=true]", text: /Card payment/
    assert_select "form#active_tender_form input[name=recording_idempotency_key]", count: 1
  end

  test "invalid first cash tender remains on tender presentation" do
    post pos_transaction_pos_tenders_path(@transaction), params: {
      tender_type_id: tender_types(:cash).id,
      amount_tendered_cents: "0",
      tender_method: "cash"
    }
    assert_redirected_to tender_pos_transaction_path(@transaction, tender_method: "cash")
    follow_redirect!
    assert_select ".pos-shell[data-pos-presentation=tender]"
    assert_select "form#active_tender_form", count: 1
  end

  test "return to transaction is available before unresolved tenders exist" do
    get tender_pos_transaction_path(@transaction)
    assert_response :success
    assert_select "a", text: "Return to Transaction"
  end
end
