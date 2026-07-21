# frozen_string_literal: true

require "test_helper"

class VendorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "index requires vendor view" do
    get vendors_url
    assert_response :success
  end

  test "create vendor" do
    assert_difference("Vendor.count", 1) do
      post vendors_url, params: {
        vendor: { code: "PENGUIN", name: "Penguin Random House", active: true }
      }
    end
    assert_redirected_to vendor_url(Vendor.order(:id).last)
  end

  test "show vendor" do
    get vendor_url(vendors(:acme_distributor))
    assert_response :success
    assert_match "Ingram", response.body
  end
end
