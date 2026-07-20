# frozen_string_literal: true

require "test_helper"

class PosPricingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @clerk = users(:clerk)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @books_department = departments(:books_new)

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer, opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
    @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    @line = Pos::AddOpenRingLine.call(
      pos_transaction: @transaction, department: @books_department, unit_price_cents: 1999, actor: @admin
    ).pos_line_item

    post session_path, params: { username: "admin", password: "password123" }
  end

  test "overriding tax category within permission redirects with a success notice" do
    patch override_tax_category_pos_transaction_pos_line_item_path(@transaction, @line),
          params: { tax_category_id: tax_categories(:stationery).id, reason: "shelving correction" }

    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal "Tax category overridden.", flash[:notice]
    assert_equal tax_categories(:stationery), @line.reload.tax_category
  end

  test "applying a transaction discount surfaces the deny path when the requester lacks authority" do
    post session_path, params: { username: "clerk", password: "password123" }

    post pos_transaction_pos_discounts_path(@transaction),
         params: { scope: "transaction", method: "percentage", rate_bps: 500 }

    assert_redirected_to pos_transaction_path(@transaction)
    assert_match(/authority/, flash[:alert])
    assert_equal 0, @transaction.pos_discounts.count
  end

  test "applying a transaction discount with an approver succeeds" do
    post session_path, params: { username: "clerk", password: "password123" }

    post pos_transaction_pos_discounts_path(@transaction),
         params: {
           scope: "transaction", method: "percentage", rate_bps: 500,
           approver_username: "admin", approver_pin: "1234"
         }

    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal 1, @transaction.pos_discounts.count
  end

  test "the transaction show page renders with lines, discounts, and tax breakdowns" do
    Pos::ApplyDiscount.call(
      pos_transaction: @transaction, scope: "line", pos_line_item: @line, method: "fixed_amount",
      amount_cents: 200, actor: @admin
    )

    get pos_transaction_path(@transaction)

    assert_response :success
    assert_select "table"
  end

  test "applying a whole-transaction tax exemption" do
    post pos_transaction_pos_tax_exemption_path(@transaction), params: { exemption_type: "resale_certificate" }

    assert_redirected_to pos_transaction_path(@transaction)
    assert @transaction.reload.tax_exempt?
  end

  test "removing a line discount clears allocations and recalculates" do
    result = Pos::ApplyDiscount.call(
      pos_transaction: @transaction, scope: "line", pos_line_item: @line,
      method: "fixed_amount", amount_cents: 200, actor: @admin
    )
    assert result.success?
    discount = result.pos_discount

    assert_difference -> { @transaction.pos_discounts.count }, -1 do
      delete pos_transaction_pos_discount_path(@transaction, discount)
    end

    assert_redirected_to pos_transaction_path(@transaction)
    assert_equal "Discount removed.", flash[:notice]
    assert_equal 0, @line.reload.discount_amount_cents
  end

  test "transaction show lists applied discounts with remove controls" do
    line_discount = Pos::ApplyDiscount.call(
      pos_transaction: @transaction, scope: "line", pos_line_item: @line,
      method: "fixed_amount", amount_cents: 100, actor: @admin
    ).pos_discount
    txn_discount = Pos::ApplyDiscount.call(
      pos_transaction: @transaction, scope: "transaction", method: "percentage",
      rate_bps: 500, actor: @admin
    ).pos_discount

    get pos_transaction_path(@transaction)
    assert_response :success
    assert_match(/Line discount/, response.body)
    assert_match(/Transaction discount/, response.body)
    assert_select "form[action=?]", pos_transaction_pos_discount_path(@transaction, line_discount)
    assert_select "form[action=?]", pos_transaction_pos_discount_path(@transaction, txn_discount)
  end
end
