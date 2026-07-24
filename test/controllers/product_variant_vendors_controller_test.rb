# frozen_string_literal: true

require "test_helper"

class ProductVariantVendorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "new form uses shared record pickers for vendor and variant" do
    get new_product_variant_vendor_path
    assert_response :success
    assert_match "data-controller=\"record-picker\"", response.body
    assert_match "data-record-picker-record-type-value=\"vendor\"", response.body
    assert_match "data-record-picker-record-type-value=\"product_variant\"", response.body
  end

  test "edit shows selected labels when foreign keys are locked" do
    source = product_variant_vendors(:sample_book_ingram)
    get edit_product_variant_vendor_path(source)
    assert_response :success
    assert_match ApplicationController.helpers.record_picker_label(source.vendor, "vendor"), response.body
    assert_match ApplicationController.helpers.record_picker_label(source.product_variant, "product_variant"), response.body
    assert_match "data-record-picker-disabled-value=\"true\"", response.body
  end
end
