# frozen_string_literal: true

require "test_helper"

class CatalogFindExistingProductTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
  end

  test "returns the product when the canonical identifier matches" do
    product = products(:sample_book)

    result = Catalog::FindExistingProduct.call(
      organization: @organization, identifier: product.identifier
    )

    assert result.found?
    assert_equal product, result.product
    assert_equal :identifier, result.match_kind
    assert_equal product.identifier, result.canonical_identifier
  end

  test "returns empty when no local product matches" do
    # Valid ISBN-13 unused by fixtures (Bookland check digit for 978014312755).
    unused = "9780143127550"

    result = Catalog::FindExistingProduct.call(
      organization: @organization, identifier: unused
    )

    assert result.empty?
    assert_nil result.product
    assert_equal :none, result.match_kind
    assert_equal unused, result.canonical_identifier
  end

  test "does not find products from another organization" do
    foreign = create_foreign_organization_catalog!
    foreign_product = foreign[:organization].products.create!(
      identifier: "9780143127741",
      identifier_generated: false,
      identifier_validation_status: "valid",
      name: "Foreign Only",
      product_type: "book",
      product_format: foreign[:product_format],
      status: "active",
      sellable: false
    )

    result = Catalog::FindExistingProduct.call(
      organization: @organization, identifier: foreign_product.identifier
    )

    assert result.empty?
  end
end
