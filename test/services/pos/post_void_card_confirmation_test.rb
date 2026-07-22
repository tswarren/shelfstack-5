# frozen_string_literal: true

require "test_helper"

module Pos
  class PostVoidCardConfirmationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @card = tender_types(:card_standalone)

      open_inventory(@variant, quantity: 2, unit_cost_cents: 400)
      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session

      sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: sale, product_variant: @variant, quantity: 1, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: sale).net_total_cents
      AddCardTender.call(
        pos_transaction: sale, tender_type: @card, amount_cents: net,
        authorization_code: "SALE-CARD-1", actor: @admin
      )
      assert CompleteTransaction.call(
        pos_transaction: sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "pv-card-sale"
      ).success?
      @sale = sale.reload
      @card_tender = @sale.pos_tenders.where(status: "completed").first
    end

    test "cannot prepare or record card confirmation without approved parent preparation" do
      denied_prepare = PreparePostVoidCardConfirmation.call(
        original_pos_tender: @card_tender, actor: @admin
      )
      refute denied_prepare.success?
      assert_match(/approved post-void preparation required/, denied_prepare.error)
    end

    test "post-void requires recorded card preparation and consumes parent approval" do
      parent = PreparePostVoid.call(
        original_transaction: @sale, actor: @admin, reason: "wrong sale",
        approver: @admin, approver_pin: "1234", pos_session: @session
      )
      assert parent.success?, parent.error
      card_prep = parent.preparation.pos_post_void_card_preparations.prepared.first
      assert card_prep.present?

      denied = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "pv-card-denied"
      )
      refute denied.success?
      assert_match(/recorded post-void card confirmation/, denied.error)

      recorded = RecordPostVoidCardConfirmation.call(
        preparation: card_prep,
        actor: @admin,
        authorization_code: "VOID-AUTH-1",
        external_void_reference: "VOID-REF-1"
      )
      assert recorded.success?, recorded.error

      result = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "pv-card-ok"
      )
      assert result.success?, result.error
      assert card_prep.reload.consumed?
      assert parent.preparation.reload.consumed?
      assert_equal parent.preparation.pos_approval_id, result.pos_transaction.post_void_pos_approval_id
      assert_equal result.pos_transaction.id, card_prep.correcting_pos_transaction_id

      reversing_tender = result.pos_transaction.pos_tenders.first
      assert_equal "VOID-AUTH-1", reversing_tender.authorization_code
      assert_equal "VOID-REF-1", reversing_tender.external_void_reference
    end

    test "recorded card preparation survives a failed post-void attempt" do
      parent = pos_ready_post_void!(
        original: @sale, actor: @admin, reason: "keep", pos_session: @session, auth_prefix: "KEEP"
      )
      card_prep = parent.pos_post_void_card_preparations.find_by!(status: "recorded")

      with_stubbed_singleton_call(EvaluatePostVoidEligibility, ->(**) {
        EvaluatePostVoidEligibility::Result.new(
          eligible?: false, blockers: [ "forced eligibility failure" ], warnings: []
        )
      }) do
        failed = PostVoidTransaction.call(
          original_transaction: @sale, pos_session: @session, actor: @admin,
          completion_idempotency_key: "pv-card-fail"
        )
        refute failed.success?
        assert_match(/forced eligibility failure/, failed.error)
      end

      assert card_prep.reload.recorded?
      assert_nil card_prep.consumed_at
      assert parent.reload.approved?
      assert_equal "KEEP-1", card_prep.authorization_code
    end

    test "late auth after abandon becomes unresolved orphan and blocks further terminal use" do
      parent = PreparePostVoid.call(
        original_transaction: @sale, actor: @admin, reason: "late auth",
        approver: @admin, approver_pin: "1234", pos_session: @session
      )
      assert parent.success?, parent.error
      card_prep = parent.preparation.pos_post_void_card_preparations.prepared.first

      assert AbandonPostVoidCardConfirmation.call(
        preparation: card_prep, actor: @admin, reason: "operator cancelled"
      ).success?

      recorded = RecordPostVoidCardConfirmation.call(
        preparation: card_prep.reload, actor: @admin, authorization_code: "LATE-1"
      )
      assert recorded.success?, recorded.error
      orphan = recorded.preparation
      assert orphan.unresolved_orphan?
      assert orphan.abandoned_at.present?
      assert_equal "LATE-1", orphan.authorization_code
      refute orphan.consumable?

      denied_prepare = PreparePostVoidCardConfirmation.call(
        original_pos_tender: @card_tender, actor: @admin
      )
      refute denied_prepare.success?
      assert_match(/unresolved post-void card orphan/, denied_prepare.error)

      denied_void = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "pv-blocked-orphan"
      )
      refute denied_void.success?
      assert_match(/unresolved post-void card orphan/, denied_void.error)

      # Parent still approved while orphan is unresolved — cannot abandon the plan.
      denied_abandon = AbandonPostVoid.call(preparation: parent.preparation.reload, actor: @admin)
      refute denied_abandon.success?
      assert_match(/reconcile orphans|already recorded/, denied_abandon.error)

      adopted = ResolvePostVoidCardOrphan.call(
        preparation: orphan, actor: @admin,
        resolution_kind: :adopt_as_confirmation, reason: "use late auth"
      )
      assert adopted.success?, adopted.error
      assert adopted.preparation.recorded?
      refute adopted.preparation.unresolved_orphan?

      result = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        completion_idempotency_key: "pv-after-adopt"
      )
      assert result.success?, result.error
      assert orphan.reload.consumed?
    end

    test "external void of orphan allows a replacement card preparation" do
      parent = PreparePostVoid.call(
        original_transaction: @sale, actor: @admin, reason: "void orphan",
        approver: @admin, approver_pin: "1234", pos_session: @session
      )
      assert parent.success?, parent.error
      card_prep = parent.preparation.pos_post_void_card_preparations.prepared.first
      assert AbandonPostVoidCardConfirmation.call(preparation: card_prep, actor: @admin).success?
      orphan = RecordPostVoidCardConfirmation.call(
        preparation: card_prep.reload, actor: @admin, authorization_code: "ORPH-2"
      ).preparation

      resolved = ResolvePostVoidCardOrphan.call(
        preparation: orphan, actor: @admin,
        resolution_kind: :external_void_confirmed,
        reason: "terminal voided the late refund",
        external_void_reference: "EXT-VOID-9"
      )
      assert resolved.success?, resolved.error
      assert orphan.reload.resolved?
      assert orphan.recorded_orphan?

      recreated = PreparePostVoidCardConfirmation.call(
        original_pos_tender: @card_tender, actor: @admin
      )
      assert recreated.success?, recreated.error
    end

    private

    def open_inventory(variant, quantity:, unit_cost_cents:)
      opening = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial), created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: opening, product_variant: variant, position: 0, quantity_delta: quantity,
        input_unit_cost_cents: unit_cost_cents, input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: opening, actor: @admin, store: @store).success?
    end
  end
end
