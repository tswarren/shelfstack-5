# frozen_string_literal: true

require "test_helper"

module Purchasing
  class ReleaseAllocationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @line = purchase_order_lines(:ordered_po_line1)
      @request = product_requests(:open_customer_request)
      @allocation = CreateAllocation.call(
        purchase_order_line: @line, product_request: @request, quantity: 2, actor: @admin, store: @store
      ).purchase_order_allocation
    end

    test "releases quantity with a structured reason" do
      result = ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 1, reason: "vendor_unavailable", actor: @admin, store: @store
      )

      assert result.success?, result.error
      assert_equal 1, result.purchase_order_allocation.remaining_quantity
      assert_equal "released", result.event.event_type
      assert_equal "vendor_unavailable", result.event.reason
    end

    test "rejects an unstructured reason" do
      result = ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 1, reason: "because I felt like it", actor: @admin, store: @store
      )

      assert_not result.success?
      assert_match(/reason must be one of/i, result.error)
    end

    test "rejects releasing more than remaining quantity" do
      result = ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 3, reason: "manual_release", actor: @admin, store: @store
      )

      assert_not result.success?
      assert_match(/exceeds remaining/i, result.error)
    end

    test "supports several partial releases up to the remaining quantity" do
      assert ReleaseAllocation.call(purchase_order_allocation: @allocation, quantity: 1, reason: "manual_release", actor: @admin, store: @store).success?

      result = ReleaseAllocation.call(purchase_order_allocation: @allocation, quantity: 1, reason: "manual_release", actor: @admin, store: @store)
      assert result.success?, result.error
      assert_equal 0, result.purchase_order_allocation.remaining_quantity

      over_release = ReleaseAllocation.call(purchase_order_allocation: @allocation, quantity: 1, reason: "manual_release", actor: @admin, store: @store)
      assert_not over_release.success?
    end

    test "replaying the same posting_key is a no-op success" do
      first = ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 1, reason: "manual_release", actor: @admin, store: @store,
        posting_key: "release-key-1"
      )
      assert first.success?, first.error
      assert_not first.replayed

      second = ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 1, reason: "manual_release", actor: @admin, store: @store,
        posting_key: "release-key-1"
      )
      assert second.success?, second.error
      assert second.replayed
      assert_equal 1, PurchaseOrderAllocationEvent.where(posting_key: "release-key-1").count
      assert_equal 1, @allocation.reload.remaining_quantity
    end

    test "reusing a posting_key with a different quantity is a conflict" do
      ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 1, reason: "manual_release", actor: @admin, store: @store,
        posting_key: "release-key-2"
      )

      result = ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 2, reason: "manual_release", actor: @admin, store: @store,
        posting_key: "release-key-2"
      )

      assert_not result.success?
      assert_match(/already used with different intent/i, result.error)
    end

    test "denies an actor without purchasing.allocation.release" do
      result = ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 1, reason: "manual_release", actor: @clerk, store: @store
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "records an audit event" do
      result = ReleaseAllocation.call(
        purchase_order_allocation: @allocation, quantity: 1, reason: "request_cancelled", actor: @admin, store: @store
      )

      assert result.success?, result.error
      event = AdministrativeAuditEvent.where(action: "purchasing.allocation.released", subject_id: @allocation.id).last
      assert event
      assert_equal "request_cancelled", event.metadata["reason"]
    end
  end
end
