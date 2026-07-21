# frozen_string_literal: true

require "test_helper"

module Catalog
  class ImportProductMetadataTest < ActiveSupport::TestCase
    setup do
      IdentifierSequence.ensure_defaults!
      @organization = organizations(:acme)
      @store = stores(:main_street)
      @actor = users(:admin)
      @merchandise_class = merchandise_classes(:fiction_primary)
      @department = departments(:books_new)
      @tax_category = tax_categories(:physical_book)
    end

    test "creates a product and standard variant from a structured attributes hash" do
      result = nil
      assert_difference [ "Product.count", "ProductVariant.count" ], 1 do
        result = ImportProductMetadata.call(
          organization: @organization, actor: @actor, store: @store,
          attrs: {
            name: "A Brand New Title", product_type: "book",
            product_format_id: product_formats(:hardcover).id,
            merchandise_class_id: @merchandise_class.id,
            default_department_id: @department.id,
            default_tax_category_id: @tax_category.id,
            list_price_cents: 1999, status: "active", sellable: true,
            inventory_tracking_mode: "quantity", regular_price_cents: 1999
          }
        )
      end

      assert result.success?, result.error
      assert_equal "A Brand New Title", result.product.name
      assert result.variant.present?
      assert_empty result.duplicate_candidates
    end

    test "warns instead of creating when the identifier already matches an existing product" do
      existing = products(:upc_product)

      result = nil
      assert_no_difference "Product.count" do
        result = ImportProductMetadata.call(
          organization: @organization, actor: @actor, store: @store,
          attrs: { identifier: existing.identifier, name: "Duplicate Attempt", product_type: "book" }
        )
      end

      assert_not result.success?
      assert_includes result.duplicate_candidates, existing
      assert result.warnings.present?
    end

    test "creates anyway when accept_duplicate_review is true" do
      existing = products(:upc_product)
      existing.update!(name: "Shared Title For Review")

      result = ImportProductMetadata.call(
        organization: @organization, actor: @actor, store: @store,
        attrs: { name: "Shared Title For Review", product_type: "book",
                 product_format_id: product_formats(:hardcover).id },
        accept_duplicate_review: true
      )

      assert result.success?, "#{result.error} / #{result.product&.errors&.full_messages}"
      assert_not_equal existing.id, result.product.id
    end

    test "warns on a likely name duplicate even without a matching identifier" do
      products(:upc_product).update!(name: "Shared Title Name")

      result = ImportProductMetadata.call(
        organization: @organization, actor: @actor, store: @store,
        attrs: { name: "Shared Title Name", product_type: "book" }
      )

      assert_not result.success?
      assert result.duplicate_candidates.any? { |p| p.name == "Shared Title Name" }
    end
  end
end
