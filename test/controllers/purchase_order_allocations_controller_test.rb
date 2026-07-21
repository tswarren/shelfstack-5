# frozen_string_literal: true

require "test_helper"

class PurchaseOrderAllocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = stores(:main_street)
    @admin = users(:admin)
    @line = purchase_order_lines(:ordered_po_line1)
    @product_request = product_requests(:open_customer_request)
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "creates an allocation and redirects to the product request by default" do
    assert_difference "PurchaseOrderAllocation.count", 1 do
      post purchase_order_allocations_path, params: {
        purchase_order_allocation: { purchase_order_line_id: @line.id, product_request_id: @product_request.id, quantity: 1 }
      }
    end

    assert_redirected_to product_request_path(@product_request)
  end

  test "creates an allocation and redirects to the purchase order when requested" do
    assert_difference "PurchaseOrderAllocation.count", 1 do
      post purchase_order_allocations_path, params: {
        purchase_order_allocation: { purchase_order_line_id: @line.id, product_request_id: @product_request.id, quantity: 1 },
        redirect_target: "purchase_order"
      }
    end

    assert_redirected_to purchase_order_path(@line.purchase_order)
  end

  test "rejects quantity exceeding uncovered quantity and does not create a record" do
    # @line's open_quantity is 5; @product_request's requested_quantity is 2 — 3
    # fits the line's open quantity but exceeds the request's uncovered quantity.
    assert_no_difference "PurchaseOrderAllocation.count" do
      post purchase_order_allocations_path, params: {
        purchase_order_allocation: { purchase_order_line_id: @line.id, product_request_id: @product_request.id, quantity: 3 }
      }
    end

    assert_redirected_to product_request_path(@product_request)
    follow_redirect!
    assert_match(/uncovered quantity/i, flash[:alert])
  end

  test "releases an allocation with a structured reason" do
    allocation = Purchasing::CreateAllocation.call(
      purchase_order_line: @line, product_request: @product_request, quantity: 2, actor: @admin, store: @store
    ).purchase_order_allocation

    post release_purchase_order_allocation_path(allocation), params: {
      purchase_order_allocation: { quantity: 1, reason: "manual_release" }
    }

    assert_redirected_to product_request_path(@product_request)
    assert_equal 1, allocation.reload.remaining_quantity
  end

  test "denies clerk without purchasing.allocation.create" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    assert_no_difference "PurchaseOrderAllocation.count" do
      post purchase_order_allocations_path, params: {
        purchase_order_allocation: { purchase_order_line_id: @line.id, product_request_id: @product_request.id, quantity: 1 }
      }
    end

    assert_redirected_to root_path
  end
end
