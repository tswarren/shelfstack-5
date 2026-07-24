# frozen_string_literal: true

require "test_helper"

class CatalogResolveRecordPickerSelectionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
  end

  test "resolves in-organization product" do
    product = products(:sample_book)

    resolved = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization,
      record_type: "product",
      id: product.id
    )

    assert_equal product, resolved
  end

  test "returns nil for blank id" do
    assert_nil Catalog::ResolveRecordPickerSelection.call(
      organization: @organization,
      record_type: "product",
      id: nil
    )
  end

  test "returns nil for foreign-organization product" do
    foreign = create_foreign_organization_catalog!

    resolved = Catalog::ResolveRecordPickerSelection.call(
      organization: @organization,
      record_type: "product",
      id: foreign[:product].id
    )

    assert_nil resolved
  end

  test "returns nil for foreign-organization variant vendor and classification" do
    foreign = create_foreign_organization_catalog!

    %w[product_variant vendor merchandise_class tax_category department product_format].each do |type|
      id = case type
      when "product_variant" then foreign[:variant].id
      when "vendor" then foreign[:vendor].id
      when "merchandise_class" then foreign[:merchandise_class].id
      when "tax_category" then foreign[:tax_category].id
      when "department" then foreign[:department].id
      when "product_format" then foreign[:product_format].id
      end

      assert_nil Catalog::ResolveRecordPickerSelection.call(
        organization: @organization,
        record_type: type,
        id: id
      ), "expected nil for foreign #{type}"
    end
  end
end
