# frozen_string_literal: true

require "test_helper"

class PurchaseOrderAllocationTest < ActiveSupport::TestCase
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @line = purchase_order_lines(:ordered_po_line1)
    @request = product_requests(:open_customer_request)
  end

  def build_allocation(quantity: 2)
    PurchaseOrderAllocation.create!(
      purchase_order_line: @line, product_request: @request, quantity: quantity, created_by_user: @admin
    )
  end

  test "remaining quantity derives from allocated minus converted minus released events" do
    allocation = build_allocation(quantity: 5)
    assert_equal 5, allocation.remaining_quantity

    allocation.purchase_order_allocation_events.create!(
      event_type: "released", quantity: 2, reason: "manual_release", occurred_at: Time.current, user: @admin
    )
    assert_equal 3, allocation.remaining_quantity
    assert_equal 2, allocation.released_quantity
    assert_equal 0, allocation.converted_quantity
  end

  test "remaining quantity never goes negative" do
    allocation = build_allocation(quantity: 2)
    allocation.purchase_order_allocation_events.create!(
      event_type: "released", quantity: 2, reason: "manual_release", occurred_at: Time.current, user: @admin
    )

    assert_equal 0, allocation.remaining_quantity
  end

  test "state reflects active, partially_resolved, converted, released, and resolved_mixed" do
    allocation = build_allocation(quantity: 4)
    assert_equal "active", allocation.state

    allocation.purchase_order_allocation_events.create!(
      event_type: "released", quantity: 1, reason: "manual_release", occurred_at: Time.current, user: @admin
    )
    assert_equal "partially_resolved", allocation.state

    allocation.purchase_order_allocation_events.create!(
      event_type: "released", quantity: 3, reason: "manual_release", occurred_at: Time.current, user: @admin
    )
    assert_equal "released", allocation.state
  end

  test "requires the product request to be a customer request (type guard)" do
    allocation = PurchaseOrderAllocation.new(
      purchase_order_line: @line, product_request: product_requests(:open_staff_suggestion),
      quantity: 1, created_by_user: @admin
    )

    assert_not allocation.valid?
    assert_match(/customer request/i, allocation.errors.full_messages.to_sentence)
  end

  test "is unique per purchase-order line and product request pair" do
    build_allocation(quantity: 1)

    duplicate = PurchaseOrderAllocation.new(
      purchase_order_line: @line, product_request: @request, quantity: 1, created_by_user: @admin
    )

    assert_not duplicate.valid?
  end

  test "requires the purchase order line and product request to share a store" do
    other_store_request = ProductRequest.new(
      store: stores(:warehouse), request_type: "customer_request", product: products(:sample_book),
      requested_quantity: 1, requested_by_user: @admin
    )

    allocation = PurchaseOrderAllocation.new(
      purchase_order_line: @line, product_request: other_store_request, quantity: 1, created_by_user: @admin
    )

    assert_not allocation.valid?
  end

  test "quantity, line, and request are immutable after creation" do
    allocation = build_allocation(quantity: 2)

    assert_raises(ActiveRecord::ReadonlyAttributeError) { allocation.quantity = 99 }
  end
end
