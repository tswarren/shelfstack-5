# frozen_string_literal: true

require "test_helper"

class ReconciliationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    membership = StoreMembership.find_by!(user: @admin, store: @store)
    Authorization::AuthorityLimits.apply_administrator_defaults!(membership)

    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @cash = tender_types(:cash)

    StockBalance.find_or_create_by!(store: @store, product_variant: @variant) do |balance|
      balance.on_hand = 20
      balance.reserved = 0
      balance.unavailable = 0
      balance.inventory_value_cents = 10_000
      balance.moving_average_cost_cents = 500
      balance.cost_quality = "actual"
    end

    post session_path, params: { username: "admin", password: "password123" }
  end

  test "rejects tampered accept_evidence_unavailable on a numeric variance comparison" do
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
      pos_transaction: txn, pos_session: session, actor: @admin, completion_idempotency_key: "recon-ctrl-1"
    ).success?
    assert Pos::CloseSession.call(pos_session: session, actor: @admin, counted_cash_cents: net + 30).success?

    assembled = Reporting::AssembleSessionReconciliation.call(pos_session: session.reload, actor: @admin)
    assert assembled.success?, assembled.error
    comparison = assembled.reconciliation.reconciliation_comparisons.first

    assert_no_difference("ReconciliationResolution.count") do
      post record_reconciliation_resolution_path(assembled.reconciliation, comparison), params: {
        resolution_type: "accept_evidence_unavailable",
        explanation: "tampered from request"
      }
    end
    assert_response :redirect
    assert_match(/nonzero variance requires/i, flash[:alert].to_s)
  end
end
