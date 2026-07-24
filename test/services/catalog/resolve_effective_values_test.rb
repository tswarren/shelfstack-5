# frozen_string_literal: true

require "test_helper"

module Catalog
  class ResolveEffectiveValuesTest < ActiveSupport::TestCase
    setup do
      @product = products(:sample_book)
      @variant = product_variants(:sample_book_standard)
    end

    test "maps ResolveClassification sources to hub labels and preserves values" do
      classification = ResolveClassification.call(product: @product, variant: @variant)
      result = ResolveEffectiveValues.call(product: @product, variant: @variant)

      assert_equal classification.merchandise_class, result.merchandise_class.value
      assert_equal "Product override", result.merchandise_class.source_label
      assert_equal classification.department, result.department.value
      assert_equal classification.tax_category, result.tax_category.value
    end

    test "variant classification overrides map to Item override" do
      dept = departments(:books_new)
      tax = tax_categories(:physical_book)
      @variant.update!(department: dept, tax_category: tax)

      result = ResolveEffectiveValues.call(product: @product, variant: @variant.reload)

      assert_equal dept, result.department.value
      assert_equal "Item override", result.department.source_label
      assert_equal tax, result.tax_category.value
      assert_equal "Item override", result.tax_category.source_label
    end

    test "configured variant settings use Standard item and treat default as present" do
      policy = ReturnPolicy.create!(
        organization: organizations(:acme),
        code: "hub_test",
        name: "Hub Test Return",
        active: true,
        final_sale: false,
        return_window_days: 30
      )
      @variant.update!(
        returnability_setting: "default",
        discountability_setting: "non_discountable",
        return_policy: policy
      )

      result = ResolveEffectiveValues.call(product: @product, variant: @variant.reload)

      assert_equal "quantity", result.tracking_mode.value
      assert_equal "Standard item", result.tracking_mode.source_label
      assert_equal "default", result.returnability_setting.value
      assert_equal "Standard item", result.returnability_setting.source_label
      assert_equal "non_discountable", result.discountability_setting.value
      assert_equal policy, result.return_policy.value
      assert_equal "Standard item", result.return_policy.source_label
    end

    test "blank configured settings are Missing" do
      @variant.update!(returnability_setting: nil, discountability_setting: nil, return_policy: nil)

      result = ResolveEffectiveValues.call(product: @product, variant: @variant.reload)

      assert_nil result.returnability_setting.value
      assert_equal "Missing", result.returnability_setting.source_label
      assert_equal "Missing", result.return_policy.source_label
    end

    test "requires a variant" do
      assert_raises(ArgumentError) do
        ResolveEffectiveValues.call(product: @product, variant: nil)
      end
    end
  end
end
