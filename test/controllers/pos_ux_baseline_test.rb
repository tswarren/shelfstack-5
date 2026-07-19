# frozen_string_literal: true

require "test_helper"

# Phase 4f UX baseline (PR2): operational POS layout, currency-mask cents
# contract, actionable scan resolution, and sign-out guarding.
class PosUxBaselineTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @department = departments(:books_new)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction

    post session_path, params: { username: "admin", password: "password123" }
  end

  test "the register renders on the operational pos layout" do
    get register_path

    assert_response :success
    assert_select "body.layout-pos"
    assert_select ".workspace-landing"
  end

  test "a cash tender posts integer cents exactly as the currency mask submits them" do
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 1999, actor: @admin
    )

    # Integer cents still accepted (tests / non-UI clients).
    post pos_transaction_pos_tenders_path(@transaction),
         params: { tender_type_id: @cash.id, amount_tendered_cents: 1250 }

    assert_redirected_to pos_transaction_path(@transaction)
    tender = @transaction.pos_tenders.order(:created_at).last
    assert_equal 1250, tender.amount_cents
  end

  test "a cash tender parses a decimal-dollar amount from the named currency field" do
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 1999, actor: @admin
    )

    post pos_transaction_pos_tenders_path(@transaction),
         params: { tender_type_id: @cash.id, amount_tendered_cents: "12.50" }

    assert_redirected_to pos_transaction_path(@transaction)
    tender = @transaction.pos_tenders.order(:created_at).last
    assert_equal 1250, tender.amount_cents
  end

  test "invalid tender amount is rejected without recording a tender" do
    Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @department, unit_price_cents: 500, actor: @admin
    )

    assert_no_difference -> { @transaction.pos_tenders.count } do
      post pos_transaction_pos_tenders_path(@transaction),
           params: { tender_type_id: @cash.id, amount_tendered_cents: "abc" }
    end
    assert_redirected_to pos_transaction_path(@transaction)
    assert_match(/amount/i, flash[:alert])
  end

  test "the transaction show page uses the two-panel workspace" do
    get pos_transaction_path(@transaction)

    assert_response :success
    assert_select ".pos-workspace .pos-sale-panel"
    assert_select ".pos-workspace .pos-payment-panel"
    assert_select "[data-controller='pos-register']"
    assert_select "input.input-currency"
  end

  test "an ambiguous scan surfaces an actionable resolution region and selection adds a line" do
    products(:sample_book).update!(alternate_identifier: "SHAREDALT01")
    products(:upc_product).update!(alternate_identifier: "SHAREDALT01")

    post pos_transaction_pos_line_items_path(@transaction), params: { query: "SHAREDALT01", quantity: 3 }
    assert_redirected_to pos_transaction_path(@transaction)

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_select ".pos-scan-resolution"
    assert_match "The Illustrated Man", response.body
    assert_match "UPC Sample", response.body
    assert_select ".pos-scan-resolution input[name=quantity][value='3']"

    assert_difference -> { @transaction.pos_line_items.pending.count }, 1 do
      post pos_transaction_pos_line_items_path(@transaction),
           params: { product_variant_id: @variant.id, quantity: 3 }
    end
    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal 3, @transaction.pos_line_items.pending.last.quantity
  end

  test "a failed scan preserves the query and marks scan_outcome failed" do
    post pos_transaction_pos_line_items_path(@transaction), params: { query: "ZZZNOMATCH999" }
    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal "failed", flash[:scan_outcome]
    assert_equal "ZZZNOMATCH999", flash[:scan_query]

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_select "input#scan_query[value='ZZZNOMATCH999']"
  end

  test "sign-out is blocked while the cashier controls an open transaction" do
    delete session_path

    assert_redirected_to pos_transaction_path(@transaction)
    assert_match(/complete, suspend, or cancel/i, flash[:alert])

    # Still authenticated: the register remains reachable.
    get register_path
    assert_response :success
  end

  test "sign-out succeeds once the open transaction is suspended" do
    post suspend_pos_transaction_path(@transaction)
    assert @transaction.reload.suspended?

    delete session_path
    assert_redirected_to new_session_path
  end

  test "operational forms render on the pos layout with currency masks" do
    get new_business_day_path
    assert_response :success
    assert_select "body.layout-pos"

    get new_pos_session_path(business_day_id: @day.id)
    assert_response :success
    assert_select "body.layout-pos"
    assert_select "input.input-currency"

    get close_form_pos_session_path(@session)
    assert_response :success
    assert_select "body.layout-pos"
    assert_select "input.input-currency"
  end
end
