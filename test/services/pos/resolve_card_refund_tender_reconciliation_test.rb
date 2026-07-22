# frozen_string_literal: true

require "test_helper"

module Pos
  class ResolveCardRefundTenderReconciliationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
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

    test "missing reconcile permission is denied" do
      _, prep, = prepare_recon_refund!

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @clerk,
        outcome: :validated_and_accepted,
        reason: "confirm",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      refute denied.success?
      assert_match(/missing permission pos\.card_refund\.reconcile/, denied.error)
    end

    test "missing card_void permission is denied for external void" do
      RolePermission.find_or_create_by!(
        role: roles(:associate),
        permission: permissions(:pos_card_refund_reconcile)
      )
      _, prep, = prepare_recon_refund!

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @clerk,
        outcome: :externally_voided,
        reason: "void it",
        external_void_reference: "V-1"
      )
      refute denied.success?
      assert_match(/missing permission pos\.tender\.card_void/, denied.error)
    end

    test "missing exception approval is denied for over-capacity acceptance" do
      sale_line, card_tender = complete_card_sale(quantity: 1, key: "deny-ex")
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation

      competing = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      PosTender.create!(
        pos_transaction: competing, store: @store, tender_type: @card,
        direction: "refunded", status: "authorized", amount_cents: card_tender.amount_cents,
        authorization_code: "COMPETE", authorized_at: Time.current,
        original_pos_tender: card_tender, created_by_user: @admin
      )

      recorded = AddCardRefundTender.call(preparation: prep, authorization_code: "DENY-EX", actor: @admin)
      assert recorded.requires_reconciliation

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep.reload,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "need approval",
        exception_approver: @clerk,
        exception_approver_pin: "9999"
      )
      refute denied.success?
      assert_match(/exception approval|approver|PIN|permission/i, denied.error)
    end

    test "settlement mismatch prevents validated_and_accepted" do
      tender, prep, = prepare_recon_refund!
      tender.update_columns(amount_cents: tender.amount_cents + 50)

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "confirm",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      refute denied.success?
      assert_match(/do not settle/, denied.error)
      assert tender.reload.requires_reconciliation?
      assert_nil prep.reload.resolved_at
    end

    test "changed return quantity fails readiness before acceptance clears recon" do
      tender, prep, ret = prepare_recon_refund!
      line = ret.pos_line_items.pending.first
      line.update_columns(quantity: line.quantity + 5)

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "confirm",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      refute denied.success?
      # Net moves with quantity, so settlement fails first; either readiness
      # failure is acceptable and must leave recon uncleared.
      assert_match(/do not settle|return quantity exceeds/, denied.error)
      assert tender.reload.requires_reconciliation?
      assert_nil prep.reload.resolved_at
    end

    test "validated_and_accepted then complete succeeds and links resolution approval only on exception" do
      sale_line, card_tender = complete_card_sale(quantity: 1, key: "ok-accept")
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      prep.update_columns(expires_at: 1.hour.ago)

      recorded = AddCardRefundTender.call(preparation: prep, authorization_code: "OK-1", actor: @admin)
      assert recorded.requires_reconciliation

      resolved = ResolveCardRefundTenderReconciliation.call(
        preparation: prep.reload,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "terminal confirmed",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      assert resolved.success?, resolved.error
      refute recorded.pos_tender.reload.requires_reconciliation?
      assert_equal card_tender.id, recorded.pos_tender.original_pos_tender_id
      assert_nil prep.reload.resolution_pos_approval_id

      completed = CompleteTransaction.call(
        pos_transaction: ret, pos_session: @session, actor: @admin,
        completion_idempotency_key: "ok-accept-complete"
      )
      assert completed.success?, completed.error
    end

    test "recalculation blocker prevents validated_and_accepted" do
      tender, prep, ret = prepare_recon_refund!
      # Unresolved recon tenders lock commercial edits; plant a sale line that
      # cannot tax-calculate so readiness sees recalculation blockers.
      open_ring = PosLineItem.create!(
        pos_transaction: ret,
        line_kind: "open_ring",
        direction: "sale",
        status: "pending",
        quantity: 1,
        unit_price_cents: 500,
        department: departments(:unconfigured_tax_department),
        tax_category: tax_categories(:unconfigured_category),
        description_snapshot: "unconfigured open ring",
        position: ret.pos_line_items.maximum(:position).to_i + 1,
        created_by_user: @admin
      )
      assert open_ring.persisted?
      recalc = RecalculateTransaction.call(pos_transaction: ret.reload)
      assert recalc.blockers.any?, "expected recalculation blockers from unconfigured tax"

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "confirm",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      refute denied.success?
      assert_match(/tax|effective store tax/i, denied.error)
      assert tender.reload.requires_reconciliation?
      assert_nil prep.reload.resolved_at
    end

    test "post-voided original prevents validated_and_accepted" do
      tender, prep, = prepare_recon_refund!
      assert tender.original_pos_tender_id.present?
      sale = tender.original_pos_tender.pos_transaction
      store = Store.lock.find(@store.id)
      seq = store.next_receipt_sequence
      store.update!(next_receipt_sequence: seq + 1)
      PosTransaction.create!(
        store: @store,
        origin_pos_session: @session,
        cashier_user: @admin,
        public_id: "PV-#{SecureRandom.hex(4)}",
        opened_at: Time.current,
        status: "completed",
        completed_at: Time.current,
        completed_by_user: @admin,
        completed_pos_session: @session,
        receipt_number: "#{@store.code}-PV#{seq}",
        receipt_sequence: seq,
        reverses_pos_transaction: sale,
        net_total_cents: 0,
        subtotal_cents: 0,
        tax_total_cents: 0,
        discount_total_cents: 0
      )
      assert sale.reload.post_voided?

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "confirm",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      refute denied.success?
      assert_match(/post-voided/, denied.error)
      assert tender.reload.requires_reconciliation?
    end

    test "inflated return quantity with matched settlement fails returnable check" do
      tender, prep, ret = prepare_recon_refund!
      line = ret.pos_line_items.pending.first
      line.update_columns(quantity: line.quantity + 1)
      recalc = RecalculateTransaction.call(pos_transaction: ret.reload)
      tender.update_columns(amount_cents: -recalc.net_total_cents)

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "confirm",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      refute denied.success?
      assert_match(/return quantity exceeds/, denied.error)
      assert tender.reload.requires_reconciliation?
    end

    test "replaced without recorded replacement is denied" do
      _, prep, = prepare_recon_refund!

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @admin,
        outcome: :replaced,
        reason: "redo terminal"
      )
      refute denied.success?
      assert_match(/replacement card refund/, denied.error)
    end

    test "replaced voids recon tender only after later replacement is recorded" do
      tender, prep, ret = prepare_recon_refund!
      replacement = plant_replacement_tender!(
        ret,
        amount_cents: tender.amount_cents,
        after: tender.authorized_at
      )

      resolved = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @admin,
        outcome: :replaced,
        reason: "terminal re-run completed",
        replacement_pos_tender: replacement
      )
      assert resolved.success?, resolved.error
      assert_equal "voided", tender.reload.status
      assert_equal "replaced", prep.reload.resolution_kind
      assert_equal "authorized", replacement.reload.status
    end

    test "externally_voided requires external void reference" do
      _, prep, = prepare_recon_refund!

      denied = ResolveCardRefundTenderReconciliation.call(
        preparation: prep,
        actor: @admin,
        outcome: :externally_voided,
        reason: "voided on terminal"
      )
      refute denied.success?
      assert_match(/external void reference/, denied.error)
    end

    test "over-capacity acceptance stores resolution_pos_approval_id" do
      sale_line, card_tender = complete_card_sale(quantity: 1, key: "res-appr")
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation

      competing = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      PosTender.create!(
        pos_transaction: competing, store: @store, tender_type: @card,
        direction: "refunded", status: "authorized", amount_cents: card_tender.amount_cents,
        authorization_code: "CAP", authorized_at: Time.current,
        original_pos_tender: card_tender, created_by_user: @admin
      )

      recorded = AddCardRefundTender.call(preparation: prep, authorization_code: "RES-APPR", actor: @admin)
      assert recorded.requires_reconciliation

      resolved = ResolveCardRefundTenderReconciliation.call(
        preparation: prep.reload,
        actor: @admin,
        outcome: :validated_and_accepted,
        reason: "accept exception",
        exception_approver: @admin,
        exception_approver_pin: "1234"
      )
      assert resolved.success?, resolved.error
      assert prep.reload.resolution_pos_approval_id.present?
      assert_equal "card_refund_reconciliation", prep.resolution_pos_approval.action_type
    end

    private

    def prepare_recon_refund!
      sale_line, card_tender = complete_card_sale(quantity: 1, key: "recon-#{SecureRandom.hex(2)}")
      ret = open_return(sale_line, quantity: 1)
      due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      prep = PrepareCardRefund.call(
        pos_transaction: ret, tender_type: @card, amount_cents: due, actor: @admin,
        original_pos_tender: card_tender
      ).preparation
      prep.update_columns(expires_at: 1.hour.ago)
      recorded = AddCardRefundTender.call(
        preparation: prep, authorization_code: "RECON-#{SecureRandom.hex(2)}", actor: @admin
      )
      assert recorded.success?, recorded.error
      assert recorded.requires_reconciliation
      [ recorded.pos_tender, prep.reload, ret ]
    end

    def complete_card_sale(quantity:, key:)
      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: quantity, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCardTender.call(
        pos_transaction: sale, tender_type: @card, amount_cents: net,
        authorization_code: "SALE-#{SecureRandom.hex(2)}", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: key
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

    def plant_replacement_tender!(ret, amount_cents:, after:)
      consumed_at = after + 1.second
      replacement = PosTender.create!(
        pos_transaction: ret,
        store: @store,
        tender_type: @card,
        direction: "refunded",
        status: "authorized",
        amount_cents: amount_cents,
        authorization_code: "REPL-#{SecureRandom.hex(2)}",
        authorized_at: consumed_at,
        requires_reconciliation: false,
        created_by_user: @admin
      )
      PosCardRefundPreparation.create!(
        pos_transaction: ret,
        tender_type: @card,
        amount_cents: amount_cents,
        plan_snapshot: { "planted" => true },
        plan_fingerprint: "planted-#{SecureRandom.hex(4)}",
        fingerprint_version: 1,
        status: "recorded_tender",
        expires_at: consumed_at + 30.minutes,
        prepared_by_user: @admin,
        recorded_by_user: @admin,
        pos_tender: replacement,
        authorization_code: replacement.authorization_code,
        authorized_at: consumed_at,
        consumed_at: consumed_at,
        requires_reconciliation: false
      )
      replacement
    end
  end
end
