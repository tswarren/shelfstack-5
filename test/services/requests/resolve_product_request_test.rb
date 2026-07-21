# frozen_string_literal: true

require "test_helper"

module Requests
  class ResolveProductRequestTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      @clerk = users(:clerk)
      @staff_suggestion = product_requests(:open_staff_suggestion)
      @stock_replenishment = product_requests(:open_stock_replenishment)
      @customer_request = product_requests(:open_customer_request)
    end

    test "ordered resolution closes the request with the full requested quantity by default" do
      result = ResolveProductRequest.call(
        product_request: @staff_suggestion, resolution: "ordered", actor: @admin, store: @store
      )

      assert result.success?, result.error
      assert_equal "closed", result.product_request.status
      assert_equal "ordered", result.product_request.resolution
      assert_equal @staff_suggestion.requested_quantity, result.product_request.resolved_quantity
      assert_equal @admin, result.product_request.resolved_by_user
      assert result.product_request.resolved_at.present?
    end

    test "declined resolution sets status declined" do
      result = ResolveProductRequest.call(
        product_request: @staff_suggestion, resolution: "declined", resolution_note: "Out of print",
        actor: @admin, store: @store
      )

      assert result.success?, result.error
      assert_equal "declined", result.product_request.status
      assert_equal "Out of print", result.product_request.resolution_note
    end

    test "deferred resolution leaves the request open" do
      result = ResolveProductRequest.call(
        product_request: @stock_replenishment, resolution: "deferred", resolution_note: "Revisit next season",
        actor: @admin, store: @store
      )

      assert result.success?, result.error
      assert_equal "open", result.product_request.status
      assert_equal "deferred", result.product_request.resolution
    end

    %w[duplicate superseded no_longer_needed].each do |code|
      test "#{code} resolution closes the request" do
        result = ResolveProductRequest.call(
          product_request: @staff_suggestion, resolution: code, actor: @admin, store: @store
        )

        assert result.success?, result.error
        assert_equal "closed", result.product_request.status
        assert_equal code, result.product_request.resolution
      end
    end

    test "partial order closes the original and creates a linked follow-up for residual quantity" do
      result = ResolveProductRequest.call(
        product_request: @stock_replenishment, resolution: "ordered", resolved_quantity: 6,
        create_follow_up: true, actor: @admin, store: @store
      )

      assert result.success?, result.error
      assert_equal "closed", result.product_request.status
      assert_equal 6, result.product_request.resolved_quantity

      follow_up = result.follow_up_product_request
      assert follow_up.present?
      assert_equal 4, follow_up.requested_quantity
      assert_equal @stock_replenishment.id, follow_up.supersedes_product_request_id
      assert follow_up.open?
      assert_equal @stock_replenishment.request_type, follow_up.request_type
    end

    test "does not create a follow-up when the full quantity was ordered" do
      result = ResolveProductRequest.call(
        product_request: @stock_replenishment, resolution: "ordered", create_follow_up: true,
        actor: @admin, store: @store
      )

      assert result.success?, result.error
      assert_nil result.follow_up_product_request
    end

    test "refuses to resolve a customer request" do
      result = ResolveProductRequest.call(
        product_request: @customer_request, resolution: "ordered", actor: @admin, store: @store
      )

      assert_not result.success?
      assert_match(/customer requests/i, result.error)
      assert_equal "open", @customer_request.reload.status
    end

    test "refuses to resolve an already-closed request" do
      result = ResolveProductRequest.call(
        product_request: product_requests(:resolved_frontlist), resolution: "declined", actor: @admin, store: @store
      )

      assert_not result.success?
      assert_match(/only open requests/i, result.error)
    end

    test "denies an actor without requests.product_request.resolve" do
      result = ResolveProductRequest.call(
        product_request: @staff_suggestion, resolution: "ordered", actor: @clerk, store: @store
      )

      assert_not result.success?
      assert_match(/not permitted/i, result.error)
    end

    test "rejects an unsupported resolution code" do
      result = ResolveProductRequest.call(
        product_request: @staff_suggestion, resolution: "bogus", actor: @admin, store: @store
      )

      assert_not result.success?
      assert_match(/resolution must be one of/i, result.error)
    end
  end
end
