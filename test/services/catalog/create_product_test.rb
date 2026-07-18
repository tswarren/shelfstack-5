# frozen_string_literal: true

require "test_helper"

class CatalogCreateProductTest < ActiveSupport::TestCase
  setup do
    IdentifierSequence.ensure_defaults!
    @organization = organizations(:acme)
    @store = stores(:main_street)
    @actor = users(:admin)
    @merchandise_class = merchandise_classes(:fiction_primary)
    @department = departments(:books_new)
    @tax_category = tax_categories(:physical_book)
  end

  test "creates product and standard variant with generated identifiers" do
    service = Catalog::CreateProduct.new(
      organization: @organization,
      actor: @actor,
      store: @store,
      product_attrs: {
        name: "Local Title",
        product_type: "book",
        product_format_id: product_formats(:hardcover).id,
        merchandise_class_id: @merchandise_class.id,
        default_department_id: @department.id,
        default_tax_category_id: @tax_category.id,
        status: "active",
        sellable: true
      },
      variant_attrs: {
        inventory_tracking_mode: "quantity",
        regular_price_cents: 1299,
        sellable: true
      }
    )

    assert_difference [ "Product.count", "ProductVariant.count" ], 1 do
      assert service.call
    end

    assert_match(/\A29\d{11}\z/, service.product.identifier)
    assert service.product.identifier_generated?
    assert_match(/\A28\d{11}\z/, service.variant.sku)
  end

  test "rolls back product when variant creation fails" do
    service = Catalog::CreateProduct.new(
      organization: @organization,
      actor: @actor,
      store: @store,
      product_attrs: {
        name: "Broken Product",
        product_type: "book",
        product_format_id: product_formats(:hardcover).id
      },
      variant_attrs: {
        inventory_tracking_mode: "quantity",
        sellable: true
      }
    )

    assert_no_difference [ "Product.count", "ProductVariant.count" ] do
      assert_not service.call
    end
  end

  test "requires accept_identifier_warning for warned identifiers" do
    service = Catalog::CreateProduct.new(
      organization: @organization,
      actor: @actor,
      store: @store,
      identifier: "9781786798986",
      accept_identifier_warning: false,
      product_attrs: {
        name: "Warned Product",
        product_type: "book",
        product_format_id: product_formats(:hardcover).id
      },
      variant_attrs: {
        inventory_tracking_mode: "quantity",
        regular_price_cents: 1000,
        sellable: true
      }
    )

    assert_no_difference "Product.count" do
      assert_not service.call
    end

    assert_includes service.product.errors[:identifier].join,
                    "invalid EAN-13 check digit"
    assert_includes service.product.errors[:identifier].join,
                    "Accept identifier warning"
  end

  test "reports invalid identifier format explicitly" do
    service = Catalog::CreateProduct.new(
      organization: @organization,
      actor: @actor,
      store: @store,
      identifier: "!!",
      product_attrs: {
        name: "Bad Identifier",
        product_type: "book",
        product_format_id: product_formats(:hardcover).id
      },
      variant_attrs: {
        inventory_tracking_mode: "quantity",
        regular_price_cents: 1000,
        sellable: true
      }
    )

    assert_not service.call
    assert_includes service.product.errors[:identifier].join, "unrecognized identifier format"
  end

  test "prevents duplicate UPC and EAN equivalent identifiers" do
    existing = products(:upc_product)

    service = Catalog::CreateProduct.new(
      organization: @organization,
      actor: @actor,
      store: @store,
      identifier: "012345678905",
      product_attrs: {
        name: "Duplicate UPC",
        product_type: "book",
        product_format_id: product_formats(:hardcover).id
      },
      variant_attrs: {
        inventory_tracking_mode: "quantity",
        regular_price_cents: 1000,
        sellable: true
      }
    )

    assert_no_difference "Product.count" do
      assert_not service.call
    end

    assert_equal "0012345678905", existing.identifier
  end

  test "product identifier is readonly after create" do
    product = products(:sample_book)

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      product.update!(identifier: "9780000000000")
    end
  end

  test "skips stale sequence values already used as product identifiers" do
    IdentifierSequence.find("29").update!(next_value: 1)
    occupied = Identifiers::Generate.call(namespace: "29")
    Product.create!(
      organization: @organization,
      identifier: occupied,
      identifier_generated: true,
      identifier_validation_status: "valid",
      name: "Occupied",
      product_type: "book",
      product_format: product_formats(:hardcover),
      status: "active",
      sellable: false
    )
    IdentifierSequence.find("29").update!(next_value: 1)

    service = Catalog::CreateProduct.new(
      organization: @organization,
      actor: @actor,
      store: @store,
      product_attrs: {
        name: "After Stale Counter",
        product_type: "book",
        product_format_id: product_formats(:hardcover).id,
        status: "active",
        sellable: false
      },
      variant_attrs: {
        inventory_tracking_mode: "quantity",
        regular_price_cents: 500,
        sellable: false
      }
    )

    assert service.call
    assert_not_equal occupied, service.product.identifier
  end
end
