# frozen_string_literal: true

require "test_helper"

module Purchasing
  class CreateAllocationTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @line = purchase_order_lines(:ordered_po_line1) # open_quantity 5
      @request = product_requests(:open_customer_request) # requested_quantity 2, sample_book
    end

    test "creates an allocation for a customer request" do
      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 2, actor: @admin, store: @store)

      assert result.success?, result.error
      allocation = result.purchase_order_allocation
      assert_equal 2, allocation.quantity
      assert_equal 2, allocation.remaining_quantity
      assert_equal @admin, allocation.created_by_user
    end

    test "does not change on_hand or on_order" do
      variant = @line.product_variant
      on_order_before = Purchasing::OnOrder.call(store: @store, product_variant: variant)

      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @admin, store: @store)

      assert result.success?, result.error
      assert_equal on_order_before, Purchasing::OnOrder.call(store: @store, product_variant: variant)
      assert_nil StockBalance.find_by(store: @store, product_variant: variant)
    end

    test "refuses non-customer requests (type guard)" do
      staff_suggestion = product_requests(:open_staff_suggestion)

      result = CreateAllocation.call(purchase_order_line: @line, product_request: staff_suggestion, quantity: 1, actor: @admin, store: @store)

      assert_not result.success?
      assert_match(/customer requests/i, result.error)
    end

    test "rejects quantity exceeding the purchase-order line's open quantity" do
      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 6, actor: @admin, store: @store)

      assert_not result.success?
      assert_match(/open .* quantity/i, result.error)
    end

    test "rejects quantity exceeding the product request's uncovered quantity" do
      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 3, actor: @admin, store: @store)

      assert_not result.success?
      assert_match(/uncovered quantity/i, result.error)
    end

    test "caps uncovered quantity against active inventory reservations for the request" do
      InventoryReservation.create!(
        store: @store, product_variant: @line.product_variant, source_type: "product_request", source_id: @request.id,
        quantity: 1, status: "active", reserved_at: Time.current
      )

      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 2, actor: @admin, store: @store)
      assert_not result.success?
      assert_match(/uncovered quantity/i, result.error)

      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @admin, store: @store)
      assert result.success?, result.error
    end

    test "caps against remaining quantity of another allocation already committed to the request" do
      other_line = purchase_order_lines(:draft_po_line1)
      other_line.purchase_order.update!(status: "ordered", ordered_at: Time.current, ordered_by_user: @admin, ordered_on: Date.current)

      assert CreateAllocation.call(purchase_order_line: other_line, product_request: @request, quantity: 2, actor: @admin, store: @store).success?

      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @admin, store: @store)
      assert_not result.success?
      assert_match(/uncovered quantity/i, result.error)
    end

    test "rejects a duplicate allocation for the same line and request pair" do
      assert CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @admin, store: @store).success?

      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @admin, store: @store)
      assert_not result.success?
      assert_match(/already exists/i, result.error)
    end

    test "rejects when the purchase order is not ordered" do
      draft_line = purchase_order_lines(:draft_po_line1)

      result = CreateAllocation.call(purchase_order_line: draft_line, product_request: @request, quantity: 1, actor: @admin, store: @store)
      assert_not result.success?
      assert_match(/only ordered purchase orders/i, result.error)
    end

    test "rejects a resolved variant mismatch between the request and the line" do
      other_variant_request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: products(:upc_product),
        product_variant: product_variants(:upc_product_standard), requested_quantity: 1, requested_by_user: @admin
      )

      result = CreateAllocation.call(purchase_order_line: @line, product_request: other_variant_request, quantity: 1, actor: @admin, store: @store)
      assert_not result.success?
      assert_match(/variant/i, result.error)
    end

    test "denies an actor without purchasing.allocation.create" do
      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @clerk, store: @store)

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "rejects allocations against a cancelled customer request" do
      @request.update!(status: "cancelled")

      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @admin, store: @store)

      assert_not result.success?
      assert_match(/not open/i, result.error)
    end

    test "rejects allocations against a fulfilled customer request" do
      @request.update!(status: "fulfilled")

      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @admin, store: @store)

      assert_not result.success?
      assert_match(/not open/i, result.error)
    end

    test "records an audit event" do
      result = CreateAllocation.call(purchase_order_line: @line, product_request: @request, quantity: 1, actor: @admin, store: @store)

      assert result.success?, result.error
      event = AdministrativeAuditEvent.where(action: "purchasing.allocation.created", subject_id: result.purchase_order_allocation.id).last
      assert event
      assert_equal @admin, event.actor_user
      assert_equal 1, event.metadata["quantity"]
    end
  end
end
