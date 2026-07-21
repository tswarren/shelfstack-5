# frozen_string_literal: true

require "test_helper"

class ProductVariantVendorTest < ActiveSupport::TestCase
  test "unique per variant and vendor" do
    source = ProductVariantVendor.new(
      product_variant: product_variants(:sample_book_standard),
      vendor: vendors(:acme_distributor),
      preferred: false,
      active: true
    )
    assert_not source.valid?
    assert_includes source.errors[:vendor_id], "has already been taken"
  end

  test "fixture is valid" do
    assert product_variant_vendors(:sample_book_ingram).valid?
  end
end
