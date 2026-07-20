# frozen_string_literal: true

require "test_helper"

module Pos
  class CashSessionCountTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @cash = tender_types(:cash)
      @variant = product_variants(:sample_book_standard)

      restock!(quantity: 8)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
    end

    test "cash-enabled open requires opening cash and close requires closing count" do
      missing = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        cashier: @admin, actor: @admin
      )
      refute missing.success?
      assert_match(/opening cash is required/, missing.error)

      session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 5000, cashier: @admin, actor: @admin
      ).pos_session
      assert_equal 5000, session.opening_cash_cents
      assert PosSessionCashCount.exists?(pos_session_id: session.id, count_type: "opening")

      _line, net = complete_cash_sale(session, quantity: 1, key: "cash-count-1")

      blocked = CloseSession.call(pos_session: session, actor: @admin)
      refute blocked.success?
      assert_match(/closing cash count is required/, blocked.error)

      expected = CalculateExpectedCash.call(pos_session: session).expected_cash_cents
      assert_equal 5000 + net, expected

      closed = CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: expected + 25)
      assert closed.success?, closed.error
      session.reload
      assert session.closed?
      assert_equal expected, session.expected_cash_cents
      assert_equal expected + 25, session.counted_cash_cents
      assert_equal 25, session.cash_variance_cents
      assert PosSessionCashCount.exists?(pos_session_id: session.id, count_type: "closing")
    end

    test "failed close with open transaction does not record a closing cash count" do
      session = open_cash_session(opening_cash_cents: 1000)
      OpenTransaction.call(pos_session: session, actor: @admin)

      result = CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 1000)
      refute result.success?
      assert_match(/open transaction/, result.error)
      refute PosSessionCashCount.exists?(pos_session_id: session.id, count_type: "closing")
      assert session.reload.open?
    end

    test "close accepts a manager recount when expected cash changed after a prior count" do
      session = open_cash_session(opening_cash_cents: 2000)

      # Pre-record a closing count (legacy path), then cash activity changes expected.
      assert RecordClosingCashCount.call(pos_session: session, counted_cash_cents: 2000, actor: @admin).success?

      _line, _net = complete_cash_sale(session, quantity: 1, key: "cash-recount-1")

      expected = CalculateExpectedCash.call(pos_session: session).expected_cash_cents
      closed = CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: expected)
      assert closed.success?, closed.error
      session.reload
      assert_equal expected, session.counted_cash_cents
      assert_equal 0, session.cash_variance_cents
      assert PosSessionCashCount.exists?(pos_session_id: session.id, count_type: "manager_recount")
    end

    test "card-only sessions close without cash counts" do
      session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cashier: @admin, actor: @admin
      ).pos_session
      result = CloseSession.call(pos_session: session, actor: @admin)
      assert result.success?
      assert_nil session.reload.opening_cash_cents
    end

    test "expected cash uses tendered amount minus change, not applied minus change" do
      session = open_cash_session(opening_cash_cents: 5000)
      txn = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(
        pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net + 1000, actor: @admin
      )
      CompleteTransaction.call(
        pos_transaction: txn, pos_session: session, actor: @admin,
        completion_idempotency_key: "cash-change-1"
      )

      result = CalculateExpectedCash.call(pos_session: session)
      assert_equal net + 1000, result.cash_received_cents
      assert_equal 1000, result.change_given_cents
      assert_equal net, result.cash_received_cents - result.change_given_cents
      assert_equal 5000 + net, result.expected_cash_cents
    end

    test "cash refund reduces expected drawer cash" do
      session = open_cash_session(opening_cash_cents: 5000)
      sale_line, sale_net = complete_cash_sale(session, quantity: 1, key: "cash-refund-sale")

      ret = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
        return_reason: return_reasons(:defective), return_disposition: "return_to_stock",
        actor: @admin
      )
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: refund_due, actor: @admin
      )
      CompleteTransaction.call(
        pos_transaction: ret, pos_session: session, actor: @admin,
        completion_idempotency_key: "cash-refund-return"
      )

      result = CalculateExpectedCash.call(pos_session: session)
      assert_equal sale_net, result.cash_received_cents
      assert_equal refund_due, result.cash_refunded_cents
      assert_equal 5000, result.expected_cash_cents
    end

    test "even exchange leaves expected cash unchanged beyond the prior sale" do
      session = open_cash_session(opening_cash_cents: 4000)
      prior_line, prior_net = complete_cash_sale(session, quantity: 1, key: "exchange-even-prior")

      exchange = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: exchange, product_variant: @variant, quantity: 1, actor: @admin)
      AddLinkedReturnLine.call(
        pos_transaction: exchange, original_pos_line_item: prior_line, quantity: 1,
        return_reason: return_reasons(:defective), return_disposition: "return_to_stock",
        actor: @admin
      )
      assert_equal 0, RecalculateTransaction.call(pos_transaction: exchange).net_total_cents
      CompleteTransaction.call(
        pos_transaction: exchange, pos_session: session, actor: @admin,
        completion_idempotency_key: "exchange-even"
      )

      result = CalculateExpectedCash.call(pos_session: session)
      assert_equal 0, result.cash_refunded_cents
      assert_equal 4000 + prior_net, result.expected_cash_cents
    end

    test "net-negative exchange refund reduces expected cash by the refund amount" do
      session = open_cash_session(opening_cash_cents: 8000)
      prior_line, prior_net = complete_cash_sale(session, quantity: 2, key: "exchange-neg-prior")

      exchange = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: exchange, product_variant: @variant, quantity: 1, actor: @admin)
      AddLinkedReturnLine.call(
        pos_transaction: exchange, original_pos_line_item: prior_line, quantity: 2,
        return_reason: return_reasons(:defective), return_disposition: "return_to_stock",
        actor: @admin
      )
      net = RecalculateTransaction.call(pos_transaction: exchange).net_total_cents
      assert net.negative?
      refund = -net
      AddCashRefundTender.call(
        pos_transaction: exchange, tender_type: @cash, amount_cents: refund, actor: @admin
      )
      CompleteTransaction.call(
        pos_transaction: exchange, pos_session: session, actor: @admin,
        completion_idempotency_key: "exchange-net-negative"
      )

      result = CalculateExpectedCash.call(pos_session: session)
      assert_equal refund, result.cash_refunded_cents
      assert_equal 8000 + prior_net - refund, result.expected_cash_cents
    end

    private

    def open_cash_session(opening_cash_cents:)
      OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: opening_cash_cents, cashier: @admin, actor: @admin
      ).pos_session
    end

    def complete_cash_sale(session, quantity:, key:)
      txn = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      line = AddLine.call(
        pos_transaction: txn, product_variant: @variant, quantity: quantity, actor: @admin
      ).pos_line_item
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(
        pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin
      )
      CompleteTransaction.call(
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: key
      )
      [ line.reload, net ]
    end

    def restock!(quantity:)
      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: @variant, position: 0,
        quantity_delta: quantity, input_unit_cost_cents: 500, input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
    end
  end
end
