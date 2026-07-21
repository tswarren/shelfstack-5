# frozen_string_literal: true

require "test_helper"

class PurchaseOrderAllocationEventTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @allocation = PurchaseOrderAllocation.create!(
      purchase_order_line: purchase_order_lines(:ordered_po_line1),
      product_request: product_requests(:open_customer_request),
      quantity: 2, created_by_user: @admin
    )
  end

  test "released events require a structured reason" do
    event = PurchaseOrderAllocationEvent.new(
      purchase_order_allocation: @allocation, event_type: "released", quantity: 1, occurred_at: Time.current, user: @admin
    )

    assert_not event.valid?
    assert_includes event.errors[:reason], "is required for released events"
  end

  test "reason must be a structured code" do
    event = PurchaseOrderAllocationEvent.new(
      purchase_order_allocation: @allocation, event_type: "released", quantity: 1, reason: "because",
      occurred_at: Time.current, user: @admin
    )

    assert_not event.valid?
  end

  test "converted_to_reservation events require a receipt line and reservation" do
    event = PurchaseOrderAllocationEvent.new(
      purchase_order_allocation: @allocation, event_type: "converted_to_reservation", quantity: 1,
      occurred_at: Time.current, user: @admin
    )

    assert_not event.valid?
    assert_includes event.errors[:receipt_line], "is required for converted_to_reservation events"
    assert_includes event.errors[:inventory_reservation], "is required for converted_to_reservation events"
  end

  test "quantity cannot exceed remaining allocation quantity" do
    event = PurchaseOrderAllocationEvent.new(
      purchase_order_allocation: @allocation, event_type: "released", quantity: 3, reason: "manual_release",
      occurred_at: Time.current, user: @admin
    )

    assert_not event.valid?
    assert_includes event.errors[:quantity], "exceeds remaining allocation quantity"
  end

  test "posting_key is unique when present" do
    @allocation.purchase_order_allocation_events.create!(
      event_type: "released", quantity: 1, reason: "manual_release", occurred_at: Time.current, user: @admin,
      posting_key: "dup-key"
    )

    duplicate = PurchaseOrderAllocationEvent.new(
      purchase_order_allocation: @allocation, event_type: "released", quantity: 1, reason: "manual_release",
      occurred_at: Time.current, user: @admin, posting_key: "dup-key"
    )

    assert_not duplicate.valid?
  end

  test "events are append-only" do
    event = @allocation.purchase_order_allocation_events.create!(
      event_type: "released", quantity: 1, reason: "manual_release", occurred_at: Time.current, user: @admin
    )

    assert event.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(note: "changed") }
  end
end
