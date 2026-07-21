# frozen_string_literal: true

require "test_helper"

class BuyerReviewControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "lists open requests with replenishment snapshot columns" do
    get buyer_review_index_path
    assert_response :success
  end

  test "adds demand to a draft purchase order and resolves a non-customer request" do
    request = product_requests(:open_staff_suggestion)

    post add_to_purchase_order_path(request), params: {
      vendor_id: vendors(:acme_distributor).id, quantity: 5
    }

    assert_response :redirect
    assert_equal "closed", request.reload.status
  end

  test "denies clerk without requests.product_request.resolve" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }

    request = product_requests(:open_staff_suggestion)
    post add_to_purchase_order_path(request), params: { vendor_id: vendors(:acme_distributor).id, quantity: 1 }
    assert_redirected_to root_path
  end
end
