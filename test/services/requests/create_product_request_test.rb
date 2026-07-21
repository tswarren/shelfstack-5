# frozen_string_literal: true

require "test_helper"

module Requests
  class CreateProductRequestTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @product = products(:upc_product)
      @variant = product_variants(:upc_product_standard)
      @admin = users(:admin)
      @clerk = users(:clerk)
    end

    test "creates an open request without changing on_hand or on_order" do
      balance_before = Purchasing::OnOrder.call(store: @store, product_variant: @variant)

      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "stock_replenishment", product_id: @product.id,
                      product_variant_id: @variant.id, requested_quantity: 4, priority: "high" }
      )

      assert result.success?, result.error
      assert_equal "open", result.product_request.status
      assert_equal @admin, result.product_request.requested_by_user
      assert_equal balance_before, Purchasing::OnOrder.call(store: @store, product_variant: @variant)
      assert_nil StockBalance.find_by(store: @store, product_variant: @variant)
    end

    test "requires a product" do
      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "staff_suggestion", requested_quantity: 1 }
      )

      assert_not result.success?
      assert_match(/Product/i, result.error)
    end

    test "customer_request type does not require a variant or priority beyond default" do
      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "customer_request", product_id: @product.id,
                      requested_quantity: 1, customer_reference: "CUST-1" }
      )

      assert result.success?, result.error
      assert result.product_request.customer_request?
      assert_nil result.product_request.product_variant_id
    end

    test "denies an actor without requests.product_request.create" do
      result = CreateProductRequest.call(
        store: @store,
        actor: @clerk,
        attributes: { request_type: "staff_suggestion", product_id: @product.id, requested_quantity: 1 }
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "records an audit event" do
      result = CreateProductRequest.call(
        store: @store,
        actor: @admin,
        attributes: { request_type: "staff_suggestion", product_id: @product.id, requested_quantity: 1 }
      )

      assert result.success?, result.error
      event = AdministrativeAuditEvent.where(action: "requests.product_request.created", subject_id: result.product_request.id).last
      assert event
      assert_equal @admin, event.actor_user
    end
  end
end
