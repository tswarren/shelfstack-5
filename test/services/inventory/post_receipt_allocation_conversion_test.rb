# frozen_string_literal: true

require "test_helper"

module Inventory
  # Phase 5f: Inventory::PostReceipt converting Purchase-Order Allocations
  # into Inventory Reservations (OD-007 "receipt posting").
  class PostReceiptAllocationConversionTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @vendor = vendors(:acme_distributor)
      @admin = users(:admin)
      @variant = product_variants(:sample_book_standard)
    end

    test "converts remaining allocation quantity into an Inventory Reservation for the request" do
      po_line = build_ordered_po_line(ordered_quantity: 10)
      request = build_customer_request(quantity: 3)
      allocation = create_allocation(po_line, request, 3)

      receipt = build_receipt(po_line, accepted_quantity: 5)
      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert result.success?, result.error

      allocation.reload
      assert_equal 0, allocation.remaining_quantity

      reservation = InventoryReservation.find_by(source_type: "product_request", source_id: request.id)
      assert reservation
      assert_equal 3, reservation.quantity
      assert reservation.active?

      event = allocation.purchase_order_allocation_events.find_by(event_type: "converted_to_reservation")
      assert event
      assert_equal 3, event.quantity
      assert_equal reservation, event.inventory_reservation
      assert_equal receipt.receipt_lines.first, event.receipt_line

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 3, balance.reserved
    end

    test "partial receipt leaves unconverted remaining allocation quantity" do
      po_line = build_ordered_po_line(ordered_quantity: 10)
      request = build_customer_request(quantity: 10)
      allocation = create_allocation(po_line, request, 10)

      receipt = build_receipt(po_line, accepted_quantity: 6)
      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert result.success?, result.error

      allocation.reload
      assert_equal 4, allocation.remaining_quantity
      assert_equal 6, allocation.converted_quantity

      reservation = InventoryReservation.find_by(source_type: "product_request", source_id: request.id)
      assert_equal 6, reservation.quantity
    end

    test "deterministic conversion order: priority, then needed_by_on, then created_at" do
      po_line = build_ordered_po_line(ordered_quantity: 10)

      urgent_later_need = build_customer_request(quantity: 2, priority: "urgent", needed_by_on: Date.current + 30)
      high_no_need_date = build_customer_request(quantity: 2, priority: "high", needed_by_on: nil)
      urgent_earlier_need = build_customer_request(quantity: 2, priority: "urgent", needed_by_on: Date.current + 5)

      alloc_urgent_later = create_allocation(po_line, urgent_later_need, 2)
      alloc_high = create_allocation(po_line, high_no_need_date, 2)
      alloc_urgent_earlier = create_allocation(po_line, urgent_earlier_need, 2)

      # Only 3 of the 6 allocated units are accepted: the urgent request with
      # the earlier need-by date should convert first and in full; the other
      # urgent request gets whatever is left; the merely-high-priority
      # request (lowest rank among the three) gets nothing.
      receipt = build_receipt(po_line, accepted_quantity: 3)
      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert result.success?, result.error

      assert_equal 0, alloc_urgent_earlier.reload.remaining_quantity
      assert_equal 1, alloc_urgent_later.reload.remaining_quantity
      assert_equal 2, alloc_high.reload.remaining_quantity

      assert_equal 2, InventoryReservation.find_by(source_type: "product_request", source_id: urgent_earlier_need.id).quantity
      assert_equal 1, InventoryReservation.find_by(source_type: "product_request", source_id: urgent_later_need.id).quantity
      refute InventoryReservation.exists?(source_type: "product_request", source_id: high_no_need_date.id)
    end

    test "accepted-but-unavailable quantity is not converted to a reservation" do
      po_line = build_ordered_po_line(ordered_quantity: 10)
      request = build_customer_request(quantity: 5)
      allocation = create_allocation(po_line, request, 5)

      receipt = build_receipt(po_line, accepted_quantity: 5, accepted_unavailable_quantity: 2)
      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert result.success?, result.error

      # Only the 3 sellable units convert; 2 unavailable units remain
      # un-promised expected supply.
      assert_equal 2, allocation.reload.remaining_quantity
      reservation = InventoryReservation.find_by(source_type: "product_request", source_id: request.id)
      assert_equal 3, reservation.quantity
    end

    test "a later receipt adds onto an existing active reservation for the same request" do
      po_line1 = build_ordered_po_line(ordered_quantity: 10)
      request = build_customer_request(quantity: 6)
      create_allocation(po_line1, request, 6)

      first_receipt = build_receipt(po_line1, accepted_quantity: 2)
      assert PostReceipt.call(receipt: first_receipt, actor: @admin, store: @store).success?

      reservation = InventoryReservation.find_by(source_type: "product_request", source_id: request.id)
      assert_equal 2, reservation.quantity
      first_reservation_id = reservation.id

      second_receipt = build_receipt(po_line1, accepted_quantity: 4)
      assert PostReceipt.call(receipt: second_receipt, actor: @admin, store: @store).success?

      reservation.reload
      assert_equal first_reservation_id, reservation.id
      assert_equal 6, reservation.quantity

      balance = StockBalance.find_by!(store: @store, product_variant: @variant)
      assert_equal 6, balance.reserved
    end

    test "does not convert allocations for individually tracked variants" do
      individual_variant = product_variants(:signed_book_standard)
      po_line = build_ordered_po_line(ordered_quantity: 3, variant: individual_variant)
      request = ProductRequest.create!(
        store: @store, request_type: "customer_request", product: individual_variant.product,
        product_variant: individual_variant, requested_quantity: 2, requested_by_user: @admin
      )
      Purchasing::CreateAllocation.call(purchase_order_line: po_line, product_request: request, quantity: 2, actor: @admin, store: @store)

      receipt = Inventory::CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: [ { product_variant_id: individual_variant.id, purchase_order_line_id: po_line.id,
                               delivered_quantity: 2, accepted_quantity: 2, actual_unit_cost_cents: 1200, cost_quality: "actual" } ],
        actor: @admin, store: @store
      ).receipt

      result = PostReceipt.call(receipt: receipt, actor: @admin, store: @store)
      assert result.success?, result.error
      refute InventoryReservation.exists?(source_type: "product_request", source_id: request.id)
    end

    private

    def build_ordered_po_line(ordered_quantity:, variant: @variant)
      po = PurchaseOrder.new(vendor: @vendor)
      created = Purchasing::CreatePurchaseOrder.call(
        purchase_order: po,
        lines_attributes: [ { product_variant_id: variant.id, ordered_quantity: ordered_quantity,
                               cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 700 } ],
        actor: @admin, store: @store
      )
      raise created.error unless created.success?

      placed = Purchasing::PlacePurchaseOrder.call(purchase_order: created.purchase_order, actor: @admin, store: @store)
      raise placed.error unless placed.success?

      placed.purchase_order.purchase_order_lines.first
    end

    def build_customer_request(quantity:, priority: "normal", needed_by_on: nil)
      ProductRequest.create!(
        store: @store, request_type: "customer_request", product: @variant.product, product_variant: @variant,
        requested_quantity: quantity, priority: priority, needed_by_on: needed_by_on, requested_by_user: @admin
      )
    end

    def create_allocation(po_line, request, quantity)
      result = Purchasing::CreateAllocation.call(purchase_order_line: po_line, product_request: request, quantity: quantity, actor: @admin, store: @store)
      raise result.error unless result.success?

      result.purchase_order_allocation
    end

    def build_receipt(po_line, accepted_quantity:, accepted_unavailable_quantity: 0)
      created = Inventory::CreateReceipt.call(
        receipt: Receipt.new(vendor: @vendor),
        lines_attributes: [ { product_variant_id: po_line.product_variant_id, purchase_order_line_id: po_line.id,
                               delivered_quantity: accepted_quantity, accepted_quantity: accepted_quantity,
                               accepted_unavailable_quantity: accepted_unavailable_quantity,
                               actual_unit_cost_cents: 700, cost_quality: "actual" } ],
        actor: @admin, store: @store
      )
      raise created.error unless created.success?

      created.receipt
    end
  end
end
