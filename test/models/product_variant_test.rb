# frozen_string_literal: true

require "test_helper"

class ProductVariantTest < ActiveSupport::TestCase
  setup do
    IdentifierSequence.ensure_defaults!
  end

  test "rejects a second variant on a single-structure product" do
    product = products(:sample_book)

    variant = product.product_variants.build(
      sku: Identifiers::Generate.call(namespace: "28"),
      name: "Extra",
      inventory_tracking_mode: "quantity",
      status: "active",
      sellable: false,
      purchasable: true
    )

    assert_not variant.valid?
    assert_includes variant.errors[:base], "single products may have only one variant"
  end

  test "rejects SKU that is not a valid generated 28 identifier" do
    product = products(:sample_book)
    product.update!(sellable: false)
    PurchaseOrderLine.where(product_variant: product.product_variants).delete_all
    ProductVariantVendor.where(product_variant: product.product_variants).delete_all
    product.product_variants.destroy_all

    variant = product.product_variants.build(
      sku: "9780306406157",
      name: "Standard",
      inventory_tracking_mode: "quantity",
      status: "active",
      sellable: false,
      purchasable: true
    )

    assert_not variant.valid?
    assert_includes variant.errors[:sku], "must be a valid generated namespace 28 EAN-13"
  end

  test "cannot destroy the last variant of a sellable product" do
    variant = product_variants(:sample_book_standard)
    assert variant.product.sellable?

    assert_no_difference "ProductVariant.count" do
      assert_not variant.destroy
    end
    assert_includes variant.errors[:base], "cannot remove the last variant from a sellable product"
  end
end
