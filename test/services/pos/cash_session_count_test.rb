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

      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: @variant, position: 0, quantity_delta: 2,
        input_unit_cost_cents: 500, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store)

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

      txn = OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      CompleteTransaction.call(
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "cash-count-1"
      )

      blocked = CloseSession.call(pos_session: session, actor: @admin)
      refute blocked.success?
      assert_match(/closing cash count is required/, blocked.error)

      expected = CalculateExpectedCash.call(pos_session: session).expected_cash_cents
      assert_equal 5000 + net, expected

      assert RecordClosingCashCount.call(pos_session: session, counted_cash_cents: expected + 25, actor: @admin).success?
      closed = CloseSession.call(pos_session: session, actor: @admin)
      assert closed.success?, closed.error
      session.reload
      assert session.closed?
      assert_equal expected, session.expected_cash_cents
      assert_equal expected + 25, session.counted_cash_cents
      assert_equal 25, session.cash_variance_cents
    end

    test "card-only sessions close without cash counts" do
      session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cashier: @admin, actor: @admin
      ).pos_session
      result = CloseSession.call(pos_session: session, actor: @admin)
      assert result.success?
      assert_nil session.reload.opening_cash_cents
    end
  end
end
