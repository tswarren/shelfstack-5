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
  end
end
