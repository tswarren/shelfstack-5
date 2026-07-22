# frozen_string_literal: true

require "test_helper"

module Pos
  class AddCardRefundTenderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @card = tender_types(:card_standalone)
      IdentifierSequence.ensure_defaults!
      pos_open_inventory(store: @store, variant: @variant, quantity: 20, unit_cost_cents: 500, actor: @admin)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
    end

    test "prepare then record authorized card refund against original tender" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents

      prepared = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      )
      assert prepared.ready?, prepared.error

      recorded = AddCardRefundTender.call(
        preparation: prepared.preparation,
        authorization_code: "RFND-1",
        actor: @admin
      )
      assert recorded.success?, recorded.error
      refute recorded.requires_reconciliation
      assert_equal card_tender.id, recorded.pos_tender.original_pos_tender_id
      assert_equal card_tender.id, recorded.preparation.intended_original_pos_tender_id
      assert recorded.preparation.recorded_tender?
    end

    test "same preparation and auth is idempotent replay" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation

      first = AddCardRefundTender.call(preparation: prep, authorization_code: "RFND-1", actor: @admin)
      second = AddCardRefundTender.call(preparation: prep, authorization_code: "RFND-1", actor: @admin)
      assert first.success?
      assert second.success?
      assert_equal first.pos_tender.id, second.pos_tender.id
      assert_equal 1, ret.pos_tenders.where(direction: "refunded").count
    end

    test "same preparation with different authorization raises conflict" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation

      assert AddCardRefundTender.call(preparation: prep, authorization_code: "RFND-1", actor: @admin).success?
      conflict = AddCardRefundTender.call(preparation: prep, authorization_code: "RFND-2", actor: @admin)
      refute conflict.success?
      assert_match(/different authorization/, conflict.error)
      assert_equal 1, ret.pos_tenders.where(direction: "refunded").count
    end

    test "record without preparation is rejected at controller contract" do
      # Service requires a preparation object; blank raises.
      result = AddCardRefundTender.call(
        preparation: nil, authorization_code: "X", actor: @admin
      )
      refute result.success?
      assert_match(/preparation is required/, result.error)
    end

    test "prepared blocks complete cancel suspend and commercial edits" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      assert PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).ready?

      refute ret.reload.editable?
      assert ret.card_refund_preparation_outstanding?

      denied_complete = CompleteTransaction.call(
        pos_transaction: ret, pos_session: @session, actor: @admin,
        completion_idempotency_key: "prep-block-complete"
      )
      refute denied_complete.success?
      assert_match(/preparation is outstanding/, denied_complete.error)

      denied_cancel = CancelTransaction.call(pos_transaction: ret, actor: @admin)
      refute denied_cancel.success?
      assert_match(/preparation is outstanding/, denied_cancel.error)

      denied_suspend = SuspendTransaction.call(pos_transaction: ret, actor: @admin)
      refute denied_suspend.success?
      assert_match(/preparation is outstanding/, denied_suspend.error)

      denied_cash = AddCashRefundTender.call(
        pos_transaction: ret, tender_type: tender_types(:cash), amount_cents: due, actor: @admin,
        original_pos_tender: nil
      )
      refute denied_cash.success?
      assert_match(/preparation is outstanding/, denied_cash.error)
    end

    test "expired preparation still blocks until abandoned" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      prep.update_columns(expires_at: 1.hour.ago)

      assert ret.reload.card_refund_preparation_outstanding?
      denied = CancelTransaction.call(pos_transaction: ret, actor: @admin)
      refute denied.success?

      assert AbandonCardRefundPreparation.call(preparation: prep, actor: @admin).success?
      refute ret.reload.card_refund_preparation_outstanding?
      assert CancelTransaction.call(pos_transaction: ret, actor: @admin).success?
    end

    test "fingerprint drift records tender requiring reconciliation" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      prep.update_columns(plan_fingerprint: "stale-fingerprint")

      recorded = AddCardRefundTender.call(
        preparation: prep, authorization_code: "RFND-DRIFT", actor: @admin
      )
      assert recorded.success?, recorded.error
      assert recorded.requires_reconciliation
      assert_match(/fingerprint/, recorded.warnings.join(" "))
    end

    test "tender type deactivated after prepare still records with reconciliation" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      @card.update!(active: false)

      recorded = AddCardRefundTender.call(
        preparation: prep, authorization_code: "RFND-INACTIVE", actor: @admin
      )
      assert recorded.success?, recorded.error
      assert recorded.requires_reconciliation
      assert recorded.pos_tender.present?
    ensure
      @card.update!(active: true)
    end

    test "force-closed transaction records orphan without tender" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation

      ret.update_columns(status: "cancelled", cancelled_at: Time.current)

      recorded = AddCardRefundTender.call(
        preparation: prep, authorization_code: "RFND-ORPHAN", actor: @admin
      )
      assert recorded.success?, recorded.error
      assert recorded.preparation.recorded_orphan?
      assert_nil recorded.pos_tender
      assert_equal 0, ret.pos_tenders.where(direction: "refunded").count
      assert PosCardRefundPreparation.unresolved_orphans.exists?(id: prep.id)

      resolved = ResolveCardRefundOrphan.call(
        preparation: prep.reload,
        actor: @admin,
        resolution_kind: :external_void_confirmed,
        reason: "terminal void confirmed",
        external_void_reference: "VOID-1"
      )
      assert resolved.success?, resolved.error
      refute PosCardRefundPreparation.unresolved_orphans.exists?(id: prep.id)
    end

    test "auth against abandoned preparation is retained as orphan" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      assert AbandonCardRefundPreparation.call(preparation: prep, actor: @admin).success?

      recorded = AddCardRefundTender.call(
        preparation: prep.reload, authorization_code: "RFND-AFTER-ABANDON", actor: @admin
      )
      assert recorded.success?, recorded.error
      assert recorded.preparation.recorded_orphan?
      assert recorded.preparation.abandoned_at.present?
      assert_nil recorded.pos_tender
      assert_includes recorded.preparation.reconciliation_reasons,
                      "preparation was abandoned before authorization was recorded"
    end

    test "validated_and_accepted after capacity consumed completes with exception approval" do
      sale_line, card_tender = complete_card_sale(quantity: 1, key: "cap-sale")
      ret_a = open_return(sale_line, quantity: 1)
      due_a = -RecalculateTransaction.call(pos_transaction: ret_a).net_total_cents
      prep_a = PrepareCardRefund.call(
        pos_transaction: ret_a, tender_type: @card, amount_cents: due_a, actor: @admin,
        original_pos_tender: card_tender
      ).preparation

      # Plant a competing in-flight refund that consumes the original capacity
      # before A records (simulates another return finishing between prepare and auth).
      ret_b = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      PosTender.create!(
        pos_transaction: ret_b, store: @store, tender_type: @card,
        direction: "refunded", status: "authorized", amount_cents: card_tender.amount_cents,
        authorization_code: "CAP-COMPETE", authorized_at: Time.current,
        original_pos_tender: card_tender, created_by_user: @admin
      )

      recorded_a = AddCardRefundTender.call(
        preparation: prep_a, authorization_code: "CAP-A", actor: @admin
      )
      assert recorded_a.success?, recorded_a.error
      assert recorded_a.requires_reconciliation
      assert_nil recorded_a.pos_tender.original_pos_tender_id

      resolved = ResolveCardRefundTenderReconciliation.call(
        preparation: prep_a.reload,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "accept over-capacity card refund",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      assert resolved.success?, resolved.error
      refute recorded_a.pos_tender.reload.requires_reconciliation?
      assert_nil recorded_a.pos_tender.original_pos_tender_id
      assert recorded_a.pos_tender.pos_approval_id.present?

      # Clear competing in-flight so completion allocation is only about A.
      competing = ret_b.pos_tenders.unresolved.first
      competing.update!(status: "voided", voided_at: Time.current, voided_by_user: @admin)

      completed = CompleteTransaction.call(
        pos_transaction: ret_a, pos_session: @session, actor: @admin,
        completion_idempotency_key: "cap-a-complete"
      )
      assert completed.success?, completed.error
    end

    test "recon tender can be externally voided" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      prep.update_columns(plan_fingerprint: "stale")

      recorded = AddCardRefundTender.call(
        preparation: prep, authorization_code: "RFND-RECON", actor: @admin
      )
      assert recorded.requires_reconciliation

      resolved = ResolveCardRefundTenderReconciliation.call(
        preparation: prep.reload,
        actor: @admin,
        outcome: :externally_voided,
        reason: "wrong amount on terminal",
        external_void_reference: "VOID-RECON"
      )
      assert resolved.success?, resolved.error
      assert_equal "voided", recorded.pos_tender.reload.status
      assert prep.reload.resolved_at.present?
      assert_equal "externally_voided", prep.resolution_kind
    end

    test "generic void resolves linked preparation" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      recorded = AddCardRefundTender.call(
        preparation: prep, authorization_code: "RFND-VOID", actor: @admin
      )
      assert recorded.success?

      removed = RemoveTender.call(
        pos_tender: recorded.pos_tender, actor: @admin,
        external_void_confirmed: true, external_void_reference: "VOID-GEN",
        reason: "cashier void"
      )
      assert removed.success?, removed.error
      assert prep.reload.resolved_at.present?
      assert_equal "externally_voided", prep.resolution_kind
    end

    test "recon tender can be validated and accepted" do
      sale_line, card_tender = complete_card_sale(quantity: 1)
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      prep.update_columns(expires_at: 1.hour.ago)

      recorded = AddCardRefundTender.call(
        preparation: prep, authorization_code: "RFND-OK", actor: @admin
      )
      assert recorded.requires_reconciliation

      resolved = ResolveCardRefundTenderReconciliation.call(
        preparation: prep.reload,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "confirmed terminal match",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      assert resolved.success?, resolved.error
      refute recorded.pos_tender.reload.requires_reconciliation?
      assert_equal card_tender.id, recorded.pos_tender.original_pos_tender_id
    end

    private

    def complete_card_sale(quantity:, key: nil)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: quantity, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCardTender.call(
        pos_transaction: sale, tender_type: @card, amount_cents: net,
        authorization_code: "SALE-#{SecureRandom.hex(2)}", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: key || "card-sale-#{SecureRandom.hex(3)}"
      ).success?
      [
        sale.pos_line_items.where(status: "completed").first,
        sale.pos_tenders.where(status: "completed").first
      ]
    end

    def open_return(sale_line, quantity:)
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret, original_pos_line_item: sale_line, quantity: quantity,
        return_reason: return_reasons(:unwanted), return_disposition: "return_to_stock", actor: @admin
      ).success?
      ret
    end
  end
end
