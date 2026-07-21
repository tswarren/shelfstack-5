# frozen_string_literal: true

require "test_helper"

module Requests
  class CancelProductRequestTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @request = product_requests(:open_stock_replenishment)
    end

    test "cancels an open request" do
      result = CancelProductRequest.call(
        product_request: @request, actor: @admin, store: @store, cancellation_reason: "No longer needed"
      )

      assert result.success?, result.error
      assert_not result.replayed
      assert_equal "cancelled", result.product_request.status
      assert_equal "No longer needed", result.product_request.resolution_note
      assert_nil result.product_request.resolution
    end

    test "replaying cancellation on an already-cancelled request is a no-op success" do
      first = CancelProductRequest.call(product_request: @request, actor: @admin, store: @store)
      assert first.success?

      second = CancelProductRequest.call(product_request: @request, actor: @admin, store: @store)
      assert second.success?
      assert second.replayed
    end

    test "refuses to cancel a closed request" do
      result = CancelProductRequest.call(
        product_request: product_requests(:resolved_frontlist), actor: @admin, store: @store
      )

      assert_not result.success?
      assert_match(/only open requests/i, result.error)
    end

    test "denies an actor without requests.product_request.cancel" do
      result = CancelProductRequest.call(product_request: @request, actor: @clerk, store: @store)

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end
  end
end
