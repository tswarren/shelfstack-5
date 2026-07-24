# frozen_string_literal: true

require "test_helper"

module Reporting
  class Phase7RemediationTest < ActiveSupport::TestCase
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
        on_hand: 20, reserved: 0, unavailable: 0,
        inventory_value_cents: 10_000, moving_average_cost_cents: 500, cost_quality: "actual"
      )
    end

    test "post-void commercial effect keeps settlement balanced and close succeeds" do
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
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "pv-1"
      ).success?

      void = pos_post_void!(
        original: txn.reload, actor: @admin, reason: "test void",
        pos_session: session, key: "pv-void-1"
      )
      assert void.success?, void.error

      totals = BuildSessionTotals.call(pos_session: session)
      assert totals.settlement["balanced"], totals.settlement.inspect
      assert_equal 0, totals.commercial["net_sales_cents"]
      assert_equal 1, totals.commercial["post_void_count"]
      assert totals.commercial["post_void_commercial_effect_cents"].negative?

      close = Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 0)
      assert close.success?, close.error
      assert close.pos_session_z_report.payload.dig("identity", "store_name").present?
      assert close.pos_session_z_report.payload.key?("card_evidence")
    end

    test "nonzero variance finalize requires explained final resolution" do
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
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "var-1"
      ).success?
      assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: net + 50).success?

      assembled = AssembleSessionReconciliation.call(pos_session: session.reload, actor: @admin)
      assert assembled.success?, assembled.error
      blocked = FinalizeReconciliation.call(reconciliation: assembled.reconciliation, actor: @admin)
      assert_not blocked.success?
      assert_match(/final resolution|explained/, blocked.error)

      comparison = assembled.reconciliation.reconciliation_comparisons.first
      recorded = RecordReconciliationResolution.call(
        reconciliation: assembled.reconciliation,
        actor: @admin,
        reconciliation_comparison: comparison,
        resolution_type: "accepted_variance",
        explanation: "Counted over; accepted within authority"
      )
      assert recorded.success?, recorded.error
      finalized = FinalizeReconciliation.call(reconciliation: assembled.reconciliation.reload, actor: @admin)
      assert finalized.success?, finalized.error
    end

    test "mixed recorded and unavailable card evidence is rejected" do
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 0).success?
      session_recon = AssembleSessionReconciliation.call(pos_session: session.reload, actor: @admin)
      assert FinalizeReconciliation.call(reconciliation: session_recon.reconciliation, actor: @admin).success?

      day.update!(status: "closed", closed_at: Time.current, closed_by_user: @admin)
      PosCloseCardEvidence.create!(
        store: @store, business_day: day, kind: "machine_batch", status: "recorded",
        precision: "net_only", net_cents: 100, entered_by_user: @admin, entered_at: Time.current
      )
      PosCloseCardEvidence.create!(
        store: @store, business_day: day, kind: "machine_batch", status: "unavailable",
        unavailable_reason: "printer down", entered_by_user: @admin, entered_at: Time.current
      )

      result = AssembleBusinessDayReconciliation.call(business_day: day.reload, actor: @admin)
      assert_not result.success?
      assert_match(/mix recorded and unavailable/, result.error)
    end

    test "activity_rebuild detects component mismatch even when net tenders match" do
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
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "cmp-1"
      ).success?
      assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: net).success?

      z = session.reload.pos_session_z_report
      payload = z.payload.deep_dup
      payload["commercial"]["gross_sales_cents"] = payload["commercial"]["gross_sales_cents"].to_i + 500
      payload["commercial"]["discount_total_cents"] = payload["commercial"]["discount_total_cents"].to_i + 500
      z.update_columns(payload: payload)

      day.update!(status: "closed", closed_at: Time.current, closed_by_user: @admin)
      final = BuildBusinessDayTotals.call(business_day: day, mode: :final, source_cutoff_at: day.closed_at)
      activity = BuildBusinessDayTotals.call(business_day: day, mode: :activity_rebuild, source_cutoff_at: day.closed_at)
      assert_equal final.settlement["net_tenders_cents"], activity.settlement["net_tenders_cents"]
      assert_not_equal final.commercial["gross_sales_cents"], activity.commercial["gross_sales_cents"]
    end

    test "store SV activity does not emit cache mismatches" do
      report = StoredValueLiabilityReport.call(organization: @store.organization, store: @store)
      assert_equal [], report.cache_ledger_mismatches
      assert report.respond_to?(:net_ledger_effect_cents)
    end

    test "session reconciliation requirement ignores card-only session without card tenders under session grain" do
      @store.update_columns(card_reconciliation_grain: "session")
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      card_device = PosDevice.create!(
        store: @store, code: "card_only_#{SecureRandom.hex(2)}", name: "Card Only",
        device_type: "register", active: true
      )
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: card_device, cash_drawer: nil,
        opening_cash_cents: nil, cashier: @admin, actor: @admin
      ).pos_session
      assert Pos::CloseSession.call(pos_session: session, actor: @admin).success?
      refute SessionReconciliationRequirement.required?(session.reload)
    ensure
      @store.update_columns(card_reconciliation_grain: "business_day")
    end

    test "finalized reconciliation comparisons are immutable" do
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 0).success?
      assembled = AssembleSessionReconciliation.call(pos_session: session.reload, actor: @admin)
      assert FinalizeReconciliation.call(reconciliation: assembled.reconciliation, actor: @admin).success?
      comparison = assembled.reconciliation.reconciliation_comparisons.first
      assert_raises(ActiveRecord::ReadOnlyRecord) { comparison.update!(variance_cents: 1) }
    end

    test "commercial report groups by reporting_date" do
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
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "date-1"
      ).success?

      rows = CommercialActivityReport.call(
        store: @store,
        from_date: day.reporting_date,
        to_date: day.reporting_date
      )
      assert rows.any?
      assert_equal day.reporting_date, rows.first.completed_on
    end
  end
end
