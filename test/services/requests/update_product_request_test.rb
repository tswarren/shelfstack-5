# frozen_string_literal: true

require "test_helper"

module Requests
  class UpdateProductRequestTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @request = product_requests(:open_stock_replenishment)
    end

    test "updates mutable attributes while open" do
      result = UpdateProductRequest.call(
        product_request: @request, actor: @admin, store: @store,
        attributes: { requested_quantity: 20, priority: "urgent", notes: "Bestseller restock" }
      )

      assert result.success?, result.error
      assert_equal 20, result.product_request.requested_quantity
      assert_equal "urgent", result.product_request.priority
      assert_equal "Bestseller restock", result.product_request.notes
    end

    test "refuses to edit a closed request" do
      result = UpdateProductRequest.call(
        product_request: product_requests(:resolved_frontlist), actor: @admin, store: @store,
        attributes: { requested_quantity: 99 }
      )

      assert_not result.success?
      assert_match(/only open requests/i, result.error)
    end

    test "denies an actor without requests.product_request.edit" do
      result = UpdateProductRequest.call(
        product_request: @request, actor: @clerk, store: @store,
        attributes: { requested_quantity: 20 }
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "reducing requested quantity releases excess allocations" do
      variant = product_variants(:sample_book_standard)
      request = product_requests(:open_customer_request)
      request.update!(product_variant: variant, requested_quantity: 5)

      vendor = vendors(:acme_distributor)
      po = Purchasing::CreatePurchaseOrder.call(
        purchase_order: PurchaseOrder.new(vendor: vendor),
        lines_attributes: [ {
          product_variant_id: variant.id, ordered_quantity: 5,
          cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 700
        } ],
        actor: @admin, store: @store
      ).purchase_order
      Purchasing::PlacePurchaseOrder.call(purchase_order: po, actor: @admin, store: @store)
      allocation = Purchasing::CreateAllocation.call(
        purchase_order_line: po.purchase_order_lines.first,
        product_request: request, quantity: 5, actor: @admin, store: @store
      ).purchase_order_allocation

      result = UpdateProductRequest.call(
        product_request: request, actor: @admin, store: @store,
        attributes: { requested_quantity: 2 }
      )

      assert result.success?, result.error
      assert_equal 2, request.reload.requested_quantity
      assert_equal 2, allocation.reload.remaining_quantity
      assert_equal "request_quantity_reduced",
                   allocation.purchase_order_allocation_events.where(event_type: "released").sole.reason
    end
  end
end
