# frozen_string_literal: true

require "test_helper"

module Reporting
  class SessionReconciliationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      membership = StoreMembership.find_by!(user: @admin, store: @store)
      Authorization::AuthorityLimits.apply_administrator_defaults!(membership)

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
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session

      txn = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      Pos::AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      @net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      Pos::AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: @net, actor: @admin)
      assert Pos::CompleteTransaction.call(
        pos_transaction: txn, pos_session: @session, actor: @admin, completion_idempotency_key: "recon-1"
      ).success?
    end

    test "exact session reconcile finalizes without inventing auto-reconcile at close" do
      close = Pos::CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: @net)
      assert close.success?, close.error
      assert_nil @session.reload.reconciled_at

      assembled = AssembleSessionReconciliation.call(pos_session: @session, actor: @admin)
      assert assembled.success?, assembled.error
      comparison = assembled.reconciliation.reconciliation_comparisons.first
      assert_equal 0, comparison.variance_cents

      finalized = FinalizeReconciliation.call(reconciliation: assembled.reconciliation, actor: @admin)
      assert finalized.success?, finalized.error
      assert @session.reload.reconciled_at.present?
      assert_equal "finalized", finalized.reconciliation.status
    end

    test "day recon waits for required session recon" do
      assert Pos::CloseSession.call(pos_session: @session, actor: @admin, counted_cash_cents: @net).success?
      assert Pos::CloseBusinessDay.call(business_day: @day, actor: @admin).success?

      blocked = AssembleBusinessDayReconciliation.call(business_day: @day, actor: @admin)
      assert_not blocked.success?
      assert_match(/pending session/, blocked.error)

      session_recon = AssembleSessionReconciliation.call(pos_session: @session.reload, actor: @admin)
      assert FinalizeReconciliation.call(reconciliation: session_recon.reconciliation, actor: @admin).success?

      day_recon = AssembleBusinessDayReconciliation.call(business_day: @day.reload, actor: @admin)
      assert day_recon.success?, day_recon.error
    end
  end
end
