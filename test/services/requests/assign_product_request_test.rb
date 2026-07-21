# frozen_string_literal: true

require "test_helper"

module Requests
  class AssignProductRequestTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @request = product_requests(:open_stock_replenishment)
    end

    test "assigns a buyer to an open request" do
      result = AssignProductRequest.call(
        product_request: @request, assigned_buyer_user: @admin, actor: @admin, store: @store
      )

      assert result.success?, result.error
      assert_equal @admin, result.product_request.assigned_buyer_user
    end

    test "refuses to assign a request that is not open" do
      result = AssignProductRequest.call(
        product_request: product_requests(:resolved_frontlist), assigned_buyer_user: @admin, actor: @admin, store: @store
      )

      assert_not result.success?
      assert_match(/only open requests/i, result.error)
    end

    test "denies an actor without requests.product_request.assign" do
      result = AssignProductRequest.call(
        product_request: @request, assigned_buyer_user: @admin, actor: @clerk, store: @store
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end
  end
end
