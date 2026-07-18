# frozen_string_literal: true

require "test_helper"

class CatalogSaleEligibilityTest < ActiveSupport::TestCase
  setup do
    @variant = product_variants(:sample_book_standard)
  end

  test "ready variant has no blockers" do
    result = Catalog::SaleEligibility.call(variant: @variant)

    assert_empty result.blockers
  end

  test "product_not_sellable when product not sellable" do
    @variant.product.update!(sellable: false)

    result = Catalog::SaleEligibility.call(variant: @variant)

    assert_includes result.blockers, "product_not_sellable"
    assert_not_includes result.blockers, "product_inactive"
  end

  test "product_inactive when product status inactive" do
    @variant.product.update!(status: "inactive", sellable: true)

    result = Catalog::SaleEligibility.call(variant: @variant)

    assert_includes result.blockers, "product_inactive"
  end

  test "variant_not_sellable when variant not sellable" do
    @variant.update!(sellable: false)

    result = Catalog::SaleEligibility.call(variant: @variant)

    assert_includes result.blockers, "variant_not_sellable"
  end

  test "missing_price when sellable without price" do
    variant = product_variants(:sample_book_standard)
    variant.regular_price_cents = nil
    variant.sellable = true

    result = Catalog::SaleEligibility.call(variant: variant)

    assert_includes result.blockers, "missing_price"
  end

  test "missing_merchandise_class when unresolved" do
    @variant.product.update!(merchandise_class: nil)
    @variant.update!(merchandise_class: nil)

    result = Catalog::SaleEligibility.call(variant: @variant)

    assert_includes result.blockers, "missing_merchandise_class"
  end

  test "missing_department when unresolved" do
    variant = product_variants(:sample_book_standard)
    product = variant.product
    merchandise_class = product.merchandise_class.dup
    merchandise_class.default_department = nil
    product.default_department = nil
    product.merchandise_class = merchandise_class
    variant.department = nil
    variant.product = product

    result = Catalog::SaleEligibility.call(variant: variant)

    assert_includes result.blockers, "missing_department"
  end

  test "department_not_postable when department is not postable" do
    @variant.department = departments(:non_postable)
    @variant.product.default_department = departments(:non_postable)

    result = Catalog::SaleEligibility.call(variant: @variant)

    assert_includes result.blockers, "department_not_postable"
  end

  test "tax_category_inactive distinct from missing" do
    tax = tax_categories(:physical_book)
    tax.update!(active: false)
    @variant.product.update!(default_tax_category: tax)
    @variant.update!(tax_category: tax)

    result = Catalog::SaleEligibility.call(variant: @variant)

    assert_includes result.blockers, "tax_category_inactive"
    assert_not_includes result.blockers, "missing_tax_category"
  end

  test "unsupported_variant_structure when not single" do
    variant = product_variants(:sample_book_standard)
    unsaved_product = variant.product.dup
    unsaved_product.variant_structure = "options"
    variant.product = unsaved_product

    result = Catalog::SaleEligibility.call(variant: variant)

    assert_includes result.blockers, "unsupported_variant_structure"
  end
end
