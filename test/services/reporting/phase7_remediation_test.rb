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

    test "commercial report groups by reporting_date even when completed_at calendar date differs" do
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

      # Force completed_at onto a different calendar day than the business-day reporting date.
      other_calendar = day.reporting_date + 2
      txn.update_columns(completed_at: other_calendar.to_time(:utc) + 12.hours)

      rows = CommercialActivityReport.call(
        store: @store,
        from_date: day.reporting_date,
        to_date: day.reporting_date
      )
      assert rows.any?
      assert_equal day.reporting_date, rows.first.completed_on
      refute_equal other_calendar, rows.first.completed_on
    end

    test "gift-card issue post-void keeps settlement balanced and close succeeds" do
      IdentifierSequence.ensure_defaults!
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account

      txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      Pos::AddStoredValueLine.call(
        pos_transaction: txn, account: account, operation: "issue", amount_cents: 2000, actor: @admin
      )
      Pos::AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: 2000, actor: @admin)
      assert Pos::CompleteTransaction.call(
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "sv-issue-pv"
      ).success?

      void = pos_post_void!(
        original: txn.reload, actor: @admin, reason: "void issue",
        pos_session: session, key: "sv-issue-pv-void"
      )
      assert void.success?, void.error

      totals = BuildSessionTotals.call(pos_session: session)
      assert_equal 0, totals.stored_value["issued_cents"]
      assert totals.settlement["balanced"], totals.settlement.inspect
      close = Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 0)
      assert close.success?, close.error
    end

    test "gift-card reload post-void keeps settlement balanced and close succeeds" do
      IdentifierSequence.ensure_defaults!
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      account = StoredValue::CreateAccount.call(
        organization: @store.organization, account_type: "gift_card", actor: @admin
      ).account
      StoredValue::PostEntry.call(
        account: account, store: @store, entry_type: "issued", amount_cents: 1000,
        posting_key: "seed-reload-issue", actor: @admin
      )

      txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      Pos::AddStoredValueLine.call(
        pos_transaction: txn, account: account, operation: "reload", amount_cents: 500, actor: @admin
      )
      Pos::AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: 500, actor: @admin)
      assert Pos::CompleteTransaction.call(
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "sv-reload-pv"
      ).success?

      void = pos_post_void!(
        original: txn.reload, actor: @admin, reason: "void reload",
        pos_session: session, key: "sv-reload-pv-void"
      )
      assert void.success?, void.error

      totals = BuildSessionTotals.call(pos_session: session)
      assert_equal 0, totals.stored_value["reloaded_cents"]
      assert totals.settlement["balanced"], totals.settlement.inspect
      close = Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 0)
      assert close.success?, close.error
    end

    test "over-threshold variance requires reporting.reconcile.approve from another user" do
      reconciler, _membership = build_reconciler_user!(threshold_cents: 0)
      _day, session, _net = close_session_with_cash_variance!(counted_delta: 75)
      assembled = AssembleSessionReconciliation.call(pos_session: session, actor: reconciler)
      assert assembled.success?, assembled.error
      comparison = assembled.reconciliation.reconciliation_comparisons.first
      assert RecordReconciliationResolution.call(
        reconciliation: assembled.reconciliation, actor: @admin,
        reconciliation_comparison: comparison, resolution_type: "accepted_variance",
        explanation: "over short"
      ).success?

      denied = FinalizeReconciliation.call(reconciliation: assembled.reconciliation, actor: reconciler)
      assert_not denied.success?
      assert_match(/approval|approver/i, denied.error)

      self_denied = FinalizeReconciliation.call(
        reconciliation: assembled.reconciliation, actor: reconciler,
        approver: reconciler, approver_pin: "9999", reason: "self without approve_self"
      )
      assert_not self_denied.success?
      assert_match(/approve_self/, self_denied.error)

      peer = User.create!(
        username: "peer_#{SecureRandom.hex(3)}",
        user_number: rand(10_000..99_999),
        first_name: "Peer",
        last_name: "Only",
        password: "password123",
        pin: "4321",
        pin_confirmation: "4321",
        active: true,
        default_store: @store
      )
      peer_role = Role.create!(
        organization: @store.organization,
        code: "peer_#{SecureRandom.hex(3)}",
        name: "Peer Session Reconcile",
        system_template: false,
        active: true
      )
      RolePermission.create!(role: peer_role, permission: permissions(:reporting_reconcile_session))
      StoreMembership.create!(
        user: peer, store: @store, role: peer_role, active: true,
        cash_variance_review_threshold_cents: 10_000
      )

      peer_denied = FinalizeReconciliation.call(
        reconciliation: assembled.reconciliation, actor: reconciler,
        approver: peer, approver_pin: "4321", reason: "peer lacks approve"
      )
      assert_not peer_denied.success?
      assert_match(/reporting\.reconcile\.approve/, peer_denied.error)

      approved = FinalizeReconciliation.call(
        reconciliation: assembled.reconciliation, actor: reconciler,
        approver: @admin, approver_pin: "1234", reason: "manager accepts variance"
      )
      assert approved.success?, approved.error
    end

    test "self-approval with approve_self finalizes over-threshold variance" do
      membership = StoreMembership.find_by!(user: @admin, store: @store)
      membership.update!(cash_variance_review_threshold_cents: 0)
      _day, session, _net = close_session_with_cash_variance!(counted_delta: 40)
      assembled = AssembleSessionReconciliation.call(pos_session: session, actor: @admin)
      comparison = assembled.reconciliation.reconciliation_comparisons.first
      assert RecordReconciliationResolution.call(
        reconciliation: assembled.reconciliation, actor: @admin,
        reconciliation_comparison: comparison, resolution_type: "explained_no_correction",
        explanation: "self-approved variance"
      ).success?

      RolePermission.joins(:permission).where(
        role: roles(:administrator),
        permissions: { code: "reporting.reconcile.approve_self" }
      ).delete_all
      denied = FinalizeReconciliation.call(
        reconciliation: assembled.reconciliation, actor: @admin,
        approver: @admin, approver_pin: "1234", reason: "no approve_self"
      )
      assert_not denied.success?
      assert_match(/approve_self/, denied.error)

      RolePermission.find_or_create_by!(
        role: roles(:administrator), permission: permissions(:reporting_reconcile_approve_self)
      )
      allowed = FinalizeReconciliation.call(
        reconciliation: assembled.reconciliation.reload, actor: @admin,
        approver: @admin, approver_pin: "1234", reason: "self approve with pin"
      )
      assert allowed.success?, allowed.error
    ensure
      RolePermission.find_or_create_by!(
        role: roles(:administrator), permission: permissions(:reporting_reconcile_approve_self)
      )
      Authorization::AuthorityLimits.apply_administrator_defaults!(membership) if membership
    end

    test "mvp resolution vocabulary rejects unresolved and bare linked_domain_correction" do
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 25).success?
      assembled = AssembleSessionReconciliation.call(pos_session: session.reload, actor: @admin)
      comparison = assembled.reconciliation.reconciliation_comparisons.first

      unresolved = RecordReconciliationResolution.call(
        reconciliation: assembled.reconciliation, actor: @admin,
        reconciliation_comparison: comparison, resolution_type: "unresolved",
        explanation: "leave it"
      )
      assert_not unresolved.success?
      assert_match(/Review later|not recorded/i, unresolved.error)

      linked = RecordReconciliationResolution.call(
        reconciliation: assembled.reconciliation, actor: @admin,
        reconciliation_comparison: comparison, resolution_type: "linked_domain_correction",
        explanation: "linked somehow"
      )
      assert_not linked.success?
      assert_match(/not available|linking/i, linked.error)

      first = RecordReconciliationResolution.call(
        reconciliation: assembled.reconciliation, actor: @admin,
        reconciliation_comparison: comparison, resolution_type: "accepted_variance",
        explanation: "accepted"
      )
      assert first.success?, first.error
      second = RecordReconciliationResolution.call(
        reconciliation: assembled.reconciliation, actor: @admin,
        reconciliation_comparison: comparison, resolution_type: "explained_no_correction",
        explanation: "second without supersede"
      )
      assert_not second.success?
      assert_match(/already has an active resolution/i, second.error)
    end

    test "finalized reconciliation header cannot return to draft and denormalized markers stay set" do
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 0).success?
      assembled = AssembleSessionReconciliation.call(pos_session: session.reload, actor: @admin)
      assert FinalizeReconciliation.call(reconciliation: assembled.reconciliation, actor: @admin).success?

      recon = assembled.reconciliation.reload
      assert recon.finalized?
      assert_raises(ActiveRecord::RecordNotSaved) do
        recon.update!(status: "draft", reconciled_at: nil, reconciled_by_user: nil)
      end
      assert recon.reload.finalized?

      session.reload
      assert session.reconciled_at.present?
      assert_raises(ActiveRecord::RecordInvalid) do
        session.update!(reconciled_at: nil, reconciled_by_user: nil)
      end
      assert session.reload.reconciled_at.present?
    end

    test "CloseBusinessDay rolls back when Session Z commercial payload is corrupted" do
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
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "day-z-corrupt"
      ).success?
      assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: net).success?

      z = session.reload.pos_session_z_report
      payload = z.payload.deep_dup
      payload["commercial"]["gross_sales_cents"] = payload["commercial"]["gross_sales_cents"].to_i + 999
      z.update_columns(payload: payload)

      result = Pos::CloseBusinessDay.call(business_day: day, actor: @admin)
      assert_not result.success?
      assert_match(/does not match|mismatch|gross_sales/i, result.error)
      assert day.reload.open?
      assert_nil day.business_day_z_report
    end

    test "discounted product post-void commercial effect nets toward zero and settles" do
      day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
      session = Pos::OpenSession.call(
        business_day: day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      txn = Pos::OpenTransaction.call(pos_session: session, actor: @admin).pos_transaction
      Pos::AddLine.call(pos_transaction: txn, product_variant: @variant, quantity: 1, actor: @admin)
      assert Pos::ApplyDiscount.call(
        pos_transaction: txn, scope: "transaction", method: "percentage",
        rate_bps: 1000, actor: @admin
      ).success?
      net = Pos::RecalculateTransaction.call(pos_transaction: txn).net_total_cents
      Pos::AddCashTender.call(pos_transaction: txn, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert Pos::CompleteTransaction.call(
        pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "disc-pv"
      ).success?

      void = pos_post_void!(
        original: txn.reload, actor: @admin, reason: "void discounted",
        pos_session: session, key: "disc-pv-void"
      )
      assert void.success?, void.error

      totals = BuildSessionTotals.call(pos_session: session)
      assert_equal 0, totals.commercial["net_sales_cents"]
      assert totals.settlement["balanced"], totals.settlement.inspect
      assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: 0).success?
    end

    private

    def build_reconciler_user!(threshold_cents:)
      role = Role.create!(
        organization: @store.organization,
        code: "day_recon_#{SecureRandom.hex(3)}",
        name: "Reconciler",
        system_template: false,
        active: true
      )
      %w[
        reporting.reconcile_session
        reporting.record_reconciliation_resolution
      ].each do |code|
        RolePermission.find_or_create_by!(role: role, permission: Permission.find_by!(code: code))
      end
      user = User.create!(
        username: "recon_#{SecureRandom.hex(3)}",
        user_number: rand(10_000..99_999),
        first_name: "Recon",
        last_name: "Clerk",
        password: "password123",
        pin: "9999",
        pin_confirmation: "9999",
        active: true,
        default_store: @store
      )
      membership = StoreMembership.create!(
        user: user, store: @store, role: role, active: true,
        cash_variance_review_threshold_cents: threshold_cents
      )
      [ user, membership ]
    end

    def close_session_with_cash_variance!(counted_delta:)
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
        pos_transaction: txn, pos_session: session, actor: @admin,
        completion_idempotency_key: "var-#{SecureRandom.hex(4)}"
      ).success?
      assert Pos::CloseSession.call(
        pos_session: session, actor: @admin, counted_cash_cents: net + counted_delta
      ).success?
      [ day, session.reload, net ]
    end
  end
end
