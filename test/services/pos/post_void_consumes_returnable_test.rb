# frozen_string_literal: true

require "test_helper"

module Pos
  class PostVoidConsumesReturnableTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @device = pos_devices(:register_1)
      @drawer = cash_drawers(:drawer_1)
      @variant = product_variants(:sample_book_standard)
      @cash = tender_types(:cash)
      open_inventory(@variant, quantity: 5, unit_cost_cents: 500)

      @day = OpenBusinessDay.call(store: @store, actor: @admin).business_day
      @session = OpenSession.call(
        business_day: @day, store: @store, pos_device: @device, cash_drawer: @drawer,
        opening_cash_cents: 0, cashier: @admin, actor: @admin
      ).pos_session
      @sale = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      AddLine.call(pos_transaction: @sale, product_variant: @variant, quantity: 2, actor: @admin)
      net = RecalculateTransaction.call(pos_transaction: @sale).net_total_cents
      AddCashTender.call(pos_transaction: @sale, tender_type: @cash, amount_tendered_cents: net, actor: @admin)
      assert CompleteTransaction.call(
        pos_transaction: @sale, pos_session: @session, actor: @admin, completion_idempotency_key: "sale-pv-ret"
      ).success?
      @sale.reload
      @sale_line = @sale.pos_line_items.where(status: "completed").find_by!(line_kind: "product")
      @sale_tender = @sale.pos_tenders.where(status: "completed").first
    end

    test "post-void zeros remaining returnable and blocks linked return" do
      assert_equal 2, @sale_line.remaining_returnable_quantity

      result = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        reason: "mistake", completion_idempotency_key: "pv-consume-1",
        approver: @admin, approver_pin: "1234"
      )
      assert result.success?, result.error

      @sale_line.reload
      assert_equal 0, @sale_line.remaining_returnable_quantity
      assert @sale_line.post_voided?
      assert @sale.reload.post_voided?
      assert_equal 0, @sale_tender.reload.remaining_refundable_cents

      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      denied = AddLinkedReturnLine.call(
        pos_transaction: ret,
        original_pos_line_item: @sale_line,
        quantity: 1,
        return_reason: return_reasons(:unwanted),
        return_disposition: "return_to_stock",
        actor: @admin
      )
      refute denied.success?
      assert_match(/post-voided/, denied.error)
    end

    test "post-void then return-complete sequencing: return completes then post-void fails" do
      ret = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      assert AddLinkedReturnLine.call(
        pos_transaction: ret,
        original_pos_line_item: @sale_line,
        quantity: 1,
        return_reason: return_reasons(:unwanted),
        return_disposition: "return_to_stock",
        actor: @admin
      ).success?
      refund_due = -RecalculateTransaction.call(pos_transaction: ret).net_total_cents
      assert AddCashRefundTender.call(
        pos_transaction: ret, tender_type: @cash, amount_cents: refund_due, actor: @admin
      ).success?
      assert CompleteTransaction.call(
        pos_transaction: ret, pos_session: @session, actor: @admin, completion_idempotency_key: "ret-first"
      ).success?

      denied = PostVoidTransaction.call(
        original_transaction: @sale, pos_session: @session, actor: @admin,
        reason: "too late", completion_idempotency_key: "pv-after-return",
        approver: @admin, approver_pin: "1234"
      )
      refute denied.success?
    end

    private

    def open_inventory(variant, quantity:, unit_cost_cents:)
      reason = inventory_adjustment_reasons(:opening_initial)
      adjustment = InventoryAdjustment.create!(
        store: @store, kind: "opening_inventory", status: "draft",
        inventory_adjustment_reason: reason, created_by_user: @admin
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment, product_variant: variant, position: 0,
        quantity_delta: quantity, input_unit_cost_cents: unit_cost_cents,
        input_cost_method: "explicit", input_cost_quality: "actual"
      )
      assert Inventory::PostAdjustment.call(adjustment: adjustment, actor: @admin, store: @store).success?
    end
  end
end
