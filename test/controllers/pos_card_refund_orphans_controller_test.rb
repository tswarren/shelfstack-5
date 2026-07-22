# frozen_string_literal: true

require "test_helper"

class PosCardRefundOrphansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @clerk = users(:clerk)
    @device = pos_devices(:register_1)
    @drawer = cash_drawers(:drawer_1)
    @variant = product_variants(:sample_book_standard)
    @card = tender_types(:card_standalone)
    IdentifierSequence.ensure_defaults!
    pos_open_inventory(store: @store, variant: @variant, quantity: 10, unit_cost_cents: 500, actor: @admin)

    @day = Pos::OpenBusinessDay.call(store: @store, actor: @admin).business_day
    @session = Pos::OpenSession.call(
      business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
      opening_cash_cents: 0, cashier: @admin, actor: @admin
    ).pos_session
  end

  test "clerk without reconcile permission is denied" do
    post session_path, params: { username: "clerk", password: "password123" }
    get pos_card_refund_orphans_path
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/not authorized/i, flash[:alert].to_s)
  end

  test "record_authorization creates orphan for abandoned preparation" do
    post session_path, params: { username: "admin", password: "password123" }
    prep = abandoned_preparation!

    post record_authorization_pos_card_refund_orphans_path, params: {
      preparation_id: prep.id,
      authorization_code: "LATE-AUTH-1",
      terminal_reference: "TERM-9"
    }
    assert_redirected_to pos_card_refund_orphans_path
    follow_redirect!
    assert_match(/orphan/i, flash[:notice])

    prep.reload
    assert prep.recorded_orphan?
    assert_equal "LATE-AUTH-1", prep.authorization_code
    assert_equal "TERM-9", prep.terminal_reference
    assert PosCardRefundPreparation.unresolved_orphans.exists?(id: prep.id)
  end

  test "resolve orphan as financial exception links resolution approval" do
    post session_path, params: { username: "admin", password: "password123" }
    prep = abandoned_preparation!
    assert Pos::AddCardRefundTender.call(
      preparation: prep, authorization_code: "ORPH-1", actor: @admin
    ).success?

    post resolve_pos_card_refund_orphan_path(prep), params: {
      resolution_kind: "accepted_financial_exception",
      reason: "terminal settled offline",
      exception_approver_username: "admin",
      exception_approver_pin: "1234"
    }
    assert_redirected_to pos_card_refund_orphans_path
    prep.reload
    assert prep.resolved?
    assert_equal "accepted_financial_exception", prep.resolution_kind
    assert prep.resolution_pos_approval_id.present?
  end

  private

  def abandoned_preparation!
    sale = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    Pos::AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
    net = Pos::RecalculateTransaction.call(pos_transaction: sale).net_total_cents
    Pos::AddCardTender.call(
      pos_transaction: sale, tender_type: @card, amount_cents: net,
      authorization_code: "SALE-CTL", actor: @admin
    )
    assert Pos::CompleteTransaction.call(
      pos_transaction: sale, pos_session: @session, actor: @admin,
      completion_idempotency_key: "ctl-orphan-sale-#{SecureRandom.hex(2)}"
    ).success?
    sale_line = sale.pos_line_items.where(status: "completed").first
    card_tender = sale.pos_tenders.where(status: "completed").first

    ret = Pos::OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
    assert Pos::AddLinkedReturnLine.call(
      pos_transaction: ret, original_pos_line_item: sale_line, quantity: 1,
      return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
    ).success?
    due = -Pos::RecalculateTransaction.call(pos_transaction: ret).net_total_cents
    prep = Pos::PrepareCardRefund.call(
      pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
      original_pos_tender: card_tender
    ).preparation
    assert Pos::AbandonCardRefundPreparation.call(preparation: prep, actor: @admin).success?
    prep.reload
  end
end
