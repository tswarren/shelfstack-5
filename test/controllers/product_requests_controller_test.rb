# frozen_string_literal: true

require "test_helper"

class ProductRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists product requests" do
    get product_requests_path
    assert_response :success
  end

  test "renders new, show, and edit" do
    get new_product_request_path
    assert_response :success
    assert_match "data-controller=\"record-picker\"", response.body
    assert_match "data-record-picker-record-type-value=\"product\"", response.body
    assert_match "data-record-picker-record-type-value=\"product_variant\"", response.body

    request = product_requests(:open_stock_replenishment)
    get product_request_path(request)
    assert_response :success

    get edit_product_request_path(request)
    assert_response :success
    assert_match ApplicationController.helpers.record_picker_label(request.product, "product"), response.body
  end

  test "creates a product request through the service" do
    assert_difference "ProductRequest.count", 1 do
      post product_requests_path, params: {
        product_request: {
          request_type: "staff_suggestion", product_id: products(:upc_product).id,
          product_variant_id: product_variants(:upc_product_standard).id, requested_quantity: 3, priority: "normal"
        }
      }
    end

    request = ProductRequest.order(:id).last
    assert_redirected_to product_request_path(request)
  end

  test "rejects creation without a product" do
    assert_no_difference "ProductRequest.count" do
      post product_requests_path, params: { product_request: { request_type: "staff_suggestion", requested_quantity: 1 } }
    end

    assert_response :unprocessable_entity
  end

  test "resolves an open non-customer request" do
    request = product_requests(:open_staff_suggestion)

    post resolve_product_request_path(request), params: { product_request: { resolution: "ordered" } }

    assert_redirected_to product_request_path(request)
    assert_equal "closed", request.reload.status
  end

  test "cancels an open request" do
    request = product_requests(:open_stock_replenishment)

    post cancel_product_request_path(request)

    assert_redirected_to product_request_path(request)
    assert_equal "cancelled", request.reload.status
  end

  test "denies clerk without requests.product_request.view" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    get product_requests_path
    assert_redirected_to root_path
  end
end
