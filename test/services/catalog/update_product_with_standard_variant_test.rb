# frozen_string_literal: true

require "test_helper"

class CatalogUpdateProductWithStandardVariantTest < ActiveSupport::TestCase
  setup do
    @product = products(:sample_book)
    @variant = product_variants(:sample_book_standard)
    @actor = users(:admin)
    @store = stores(:main_street)
  end

  test "updates product and variant atomically" do
    assert Catalog::UpdateProductWithStandardVariant.call(
      product: @product,
      variant: @variant,
      product_attrs: { name: "Renamed Illustrated Man" },
      variant_attrs: { regular_price_cents: 2222 },
      actor: @actor,
      store: @store
    )

    assert_equal "Renamed Illustrated Man", @product.reload.name
    assert_equal 2222, @variant.reload.regular_price_cents
  end

  test "rolls back product when variant update is invalid" do
    original_name = @product.name

    assert_not Catalog::UpdateProductWithStandardVariant.call(
      product: @product,
      variant: @variant,
      product_attrs: { name: "Should Not Persist" },
      variant_attrs: { sellable: true, regular_price_cents: nil },
      actor: @actor,
      store: @store
    )

    assert_equal original_name, @product.reload.name
  end
end
