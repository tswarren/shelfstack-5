# frozen_string_literal: true

require "test_helper"

module Purchasing
  class CancelPurchaseOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
    end

    test "cancels a draft purchase order" do
      po = purchase_orders(:draft_po)
      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store, cancel_reason: "no longer needed")

      assert result.success?, result.error
      assert po.reload.cancelled?
      assert_equal @user, po.cancelled_by_user
    end

    test "cancels an ordered purchase order with nothing received" do
      po = purchase_orders(:ordered_po)
      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store, cancel_reason: "vendor unavailable")

      assert result.success?, result.error
      assert po.reload.cancelled?
    end

    test "cannot cancel a purchase order with received quantity" do
      po = purchase_orders(:ordered_po)
      purchase_order_lines(:ordered_po_line1).update_column(:received_quantity, 1)

      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/received quantity/i, result.error)
      assert po.reload.ordered?
    end

    test "cannot cancel a closed purchase order" do
      po = purchase_orders(:ordered_po)
      purchase_order_lines(:ordered_po_line1).update_column(:cancelled_quantity, 5)
      po.update!(status: "closed", closed_at: Time.current, closed_by_user: @user)

      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/closed/i, result.error)
    end

    test "replaying an already-cancelled purchase order is a no-op success" do
      po = purchase_orders(:draft_po)
      assert CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store).success?

      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store)
      assert result.success?
      assert result.replayed
    end

    test "cancelling an ordered purchase order atomically releases remaining allocated quantity" do
      po = purchase_orders(:ordered_po)
      line = purchase_order_lines(:ordered_po_line1)
      allocation = Purchasing::CreateAllocation.call(
        purchase_order_line: line, product_request: product_requests(:open_customer_request),
        quantity: 2, actor: @user, store: @store
      ).purchase_order_allocation

      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store, cancel_reason: "vendor unavailable")

      assert result.success?, result.error
      assert po.reload.cancelled?
      assert_equal 0, allocation.reload.remaining_quantity
      event = allocation.purchase_order_allocation_events.last
      assert_equal "released", event.event_type
      assert_equal "purchase_order_cancelled", event.reason

      audit = AdministrativeAuditEvent.where(action: "purchasing.purchase_order.cancelled", subject_id: po.id).last
      assert_equal [ { "allocation_id" => allocation.id, "quantity" => 2 } ], audit.metadata["released_allocations"]
    end

    test "cancelling a purchase order with no remaining allocated quantity leaves resolved allocations untouched" do
      po = purchase_orders(:ordered_po)
      line = purchase_order_lines(:ordered_po_line1)
      allocation = Purchasing::CreateAllocation.call(
        purchase_order_line: line, product_request: product_requests(:open_customer_request),
        quantity: 2, actor: @user, store: @store
      ).purchase_order_allocation
      Purchasing::ReleaseAllocation.call(
        purchase_order_allocation: allocation, quantity: 2, reason: "manual_release", actor: @user, store: @store
      )

      result = CancelPurchaseOrder.call(purchase_order: po, actor: @user, store: @store)

      assert result.success?, result.error
      assert_equal 1, allocation.purchase_order_allocation_events.count
      assert_equal "manual_release", allocation.purchase_order_allocation_events.last.reason
    end
  end
end
