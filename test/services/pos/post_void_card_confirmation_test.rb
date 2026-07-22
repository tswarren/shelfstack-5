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

    test "post-void requires recorded card preparation and consumes it" do
      denied = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        reason: "wrong sale", completion_idempotency_key: "pv-card-denied",
        approver: @admin, approver_pin: "1234"
      )
      refute denied.success?
      assert_match(/recorded post-void card confirmation/, denied.error)

      prepared = PreparePostVoidCardConfirmation.call(original_pos_tender: @card_tender, actor: @admin)
      assert prepared.success?, prepared.error
      recorded = RecordPostVoidCardConfirmation.call(
        preparation: prepared.preparation,
        actor: @admin,
        authorization_code: "VOID-AUTH-1",
        external_void_reference: "VOID-REF-1"
      )
      assert recorded.success?, recorded.error

      result = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        reason: "wrong sale", completion_idempotency_key: "pv-card-ok",
        approver: @admin, approver_pin: "1234"
      )
      assert result.success?, result.error
      assert prepared.preparation.reload.consumed?
      assert_equal result.pos_transaction.id, prepared.preparation.correcting_pos_transaction_id

      reversing_tender = result.pos_transaction.pos_tenders.first
      assert_equal "VOID-AUTH-1", reversing_tender.authorization_code
      assert_equal "VOID-REF-1", reversing_tender.external_void_reference
    end

    test "recorded card preparation survives a failed post-void attempt" do
      prepared = PreparePostVoidCardConfirmation.call(original_pos_tender: @card_tender, actor: @admin)
      assert prepared.success?
      assert RecordPostVoidCardConfirmation.call(
        preparation: prepared.preparation, actor: @admin, authorization_code: "KEEP-1"
      ).success?

      RolePermission.where(
        role: roles(:administrator),
        permission: permissions(:pos_post_void_approve_self)
      ).delete_all

      failed = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        reason: "fail auth", completion_idempotency_key: "pv-card-fail",
        approver: @admin, approver_pin: "1234"
      )
      refute failed.success?

      prep = prepared.preparation.reload
      assert prep.recorded?
      assert_nil prep.consumed_at
      assert_equal "KEEP-1", prep.authorization_code
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
