# frozen_string_literal: true

require "test_helper"

module Purchasing
  class AddDemandToDraftPurchaseOrderTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @vendor = vendors(:acme_distributor)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @variant = product_variants(:upc_product_standard)
      @staff_suggestion = product_requests(:open_staff_suggestion)
      @stock_replenishment = product_requests(:open_stock_replenishment)
      @customer_request = product_requests(:open_customer_request)
    end

    test "adds a line to the existing draft purchase order for the vendor" do
      draft = purchase_orders(:draft_po)

      result = AddDemandToDraftPurchaseOrder.call(
        store: @store, vendor: @vendor, product_request: @staff_suggestion, quantity: 5, actor: @admin
      )

      assert result.success?, result.error
      assert_equal draft.id, result.purchase_order.id
      assert_equal @variant.id, result.purchase_order_line.product_variant_id
      assert_equal 5, result.purchase_order_line.ordered_quantity
      assert_equal product_variant_vendors(:upc_product_ingram).id, result.purchase_order_line.product_variant_vendor_id
    end

    test "creates a new draft purchase order when none exists for the vendor" do
      other_vendor = vendors(:small_press_direct)

      result = AddDemandToDraftPurchaseOrder.call(
        store: @store, vendor: other_vendor, product_request: @stock_replenishment, quantity: 3,
        actor: @admin, cost_entry_method: "direct_net_cost", expected_unit_cost_cents: 500
      )

      assert result.success?, result.error
      assert result.purchase_order.persisted?
      assert_equal "draft", result.purchase_order.status
      assert_equal other_vendor.id, result.purchase_order.vendor_id
      assert_not_equal purchase_orders(:draft_po).id, result.purchase_order.id
    end

    test "resolves a non-customer request as ordered without creating an allocation" do
      result = AddDemandToDraftPurchaseOrder.call(
        store: @store, vendor: @vendor, product_request: @staff_suggestion, quantity: 5, actor: @admin
      )

      assert result.success?, result.error
      assert_equal "closed", result.product_request.status
      assert_equal "ordered", result.product_request.resolution
      assert_equal 5, result.product_request.resolved_quantity
      assert_equal 0, PurchaseOrderAllocation.count if defined?(PurchaseOrderAllocation)
    end

    test "adds demand for a customer request without resolving or closing it" do
      customer_variant = product_variants(:sample_book_standard)
      assert_equal @customer_request.product_id, customer_variant.product_id

      result = AddDemandToDraftPurchaseOrder.call(
        store: @store, vendor: @vendor, product_request: @customer_request,
        product_variant: customer_variant, quantity: 2, actor: @admin
      )

      assert result.success?, result.error
      assert_equal @customer_request.id, result.product_request.id
      assert_equal "open", @customer_request.reload.status
      assert_nil @customer_request.resolution
    end

    test "does not resolve the request when resolve_request is false" do
      result = AddDemandToDraftPurchaseOrder.call(
        store: @store, vendor: @vendor, product_request: @staff_suggestion, quantity: 5,
        actor: @admin, resolve_request: false
      )

      assert result.success?, result.error
      assert_equal "open", @staff_suggestion.reload.status
    end

    test "fails without a resolved product variant" do
      request = ProductRequest.create!(
        store: @store, request_type: "staff_suggestion", product: products(:upc_product),
        requested_quantity: 1, requested_by_user: @admin
      )

      result = AddDemandToDraftPurchaseOrder.call(
        store: @store, vendor: @vendor, product_request: request, quantity: 1, actor: @admin
      )

      assert_not result.success?
      assert_match(/variant must be resolved/i, result.error)
    end

    test "denies an actor without purchasing.purchase_order.create" do
      result = AddDemandToDraftPurchaseOrder.call(
        store: @store, vendor: @vendor, product_request: @staff_suggestion, quantity: 5, actor: @clerk
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "explicit purchase_order target must be draft" do
      ordered = purchase_orders(:ordered_po)

      result = AddDemandToDraftPurchaseOrder.call(
        store: @store, vendor: @vendor, product_request: @staff_suggestion, quantity: 1,
        actor: @admin, purchase_order: ordered
      )

      assert_not result.success?
      assert_match(/only draft purchase orders/i, result.error)
    end
  end
end
