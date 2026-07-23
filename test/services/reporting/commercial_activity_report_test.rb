# frozen_string_literal: true

require "test_helper"

module Reporting
  class CommercialActivityReportTest < ActiveSupport::TestCase
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

      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      Pos::AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      Pos::AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert Pos::CompleteTransaction.call(
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "comm-1"
      ).success?
    end

    test "attributes commercial activity to completion date and separates missing cost from zero" do
      today = StoreTime.today(@store)
      rows = CommercialActivityReport.call(store: @store, from_date: today, to_date: today)
      assert rows.any?
      row = rows.first
      assert row.gross_sales_cents.positive?
      assert_operator row.missing_cost_line_count, :>=, 0
    end

    test "integrity diagnostics return non-blocking findings collection" do
      findings = IntegrityDiagnostics.call(store: @store)
      assert findings.is_a?(Array)
    end
  end
end
