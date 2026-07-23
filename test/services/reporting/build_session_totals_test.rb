# frozen_string_literal: true

require "test_helper"

module Reporting
  class BuildSessionTotalsTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)

      StockBalance.create!(
        store: @store, product_variant: @variant,
        on_hand: 5, reserved: 0, unavailable: 0,
        inventory_value_cents: 2500, moving_average_cost_cents: 500, cost_quality: "actual"
      )

      @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = Pos::OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 1000, cashier: @admin, actor: @admin
      ).pos_session
      @transaction = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    end

    test "attributes commercial totals to completed_pos_session_id" do
      Pos::AddLine.call(pos_transaction: @transaction, product_variant: @variant, quantity: 1, actor: @admin)
      net = Pos::RecalculateTransaction.call(pos_transaction: @transaction).net_total_cents
      Pos::AddCashTender.call(
        pos_transaction: @transaction, tender_type: @cash, amount_tendered_cents: net, actor: @admin
      )
      complete = Pos::CompleteTransaction.call(
        pos_transaction: @transaction, pos_session: @session, actor: @admin,
        completion_idempotency_key: "rpt-1"
      )
      assert complete.success?, complete.error

      totals = BuildSessionTotals.call(pos_session: @session)

      assert_equal ReportDefinition::VERSION, totals.report_definition_version
      assert totals.commercial["gross_sales_cents"].positive?
      assert_equal 1, totals.activity_counts["completed_transactions"]
      assert totals.settlement.key?("balanced")
      assert_equal @session.id, totals.to_payload["pos_session_id"]
    end

    test "live X does not mutate session or create Z" do
      before = PosSessionZReport.count
      BuildSessionTotals.call(pos_session: @session)
      assert_equal before, PosSessionZReport.count
      assert @session.reload.open?
    end
  end
end
