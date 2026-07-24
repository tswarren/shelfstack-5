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

  test "validation rerender does not disclose foreign-organization vendor labels" do
    foreign = create_foreign_organization_catalog!
    local_variant = product_variants(:sample_book_standard)

    assert_no_difference "ProductVariantVendor.count" do
      post product_variant_vendors_path, params: {
        product_variant_vendor: {
          vendor_id: foreign[:vendor].id,
          product_variant_id: local_variant.id,
          preferred: false,
          active: true
        }
      }
    end

    assert_response :unprocessable_entity
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_VENDOR_NAME)}/, response.body)
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_VENDOR_CODE)}/, response.body)
    assert_match(/must belong to the same organization/, response.body)
  end

  test "validation rerender does not disclose foreign-organization variant labels" do
    foreign = create_foreign_organization_catalog!
    local_vendor = vendors(:acme_distributor)

    assert_no_difference "ProductVariantVendor.count" do
      post product_variant_vendors_path, params: {
        product_variant_vendor: {
          vendor_id: local_vendor.id,
          product_variant_id: foreign[:variant].id,
          preferred: false,
          active: true
        }
      }
    end

    assert_response :unprocessable_entity
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_VARIANT_SKU)}/, response.body)
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_PRODUCT_NAME)}/, response.body)
    assert_no_match(/#{Regexp.escape(ForeignOrganizationHelper::SECRET_VARIANT_NAME)}/, response.body)
    assert_match(/must belong to the same organization/, response.body)
  end
end
