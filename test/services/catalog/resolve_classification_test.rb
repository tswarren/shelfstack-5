# frozen_string_literal: true

require "test_helper"

module Catalog
  class ResolveClassificationTest < ActiveSupport::TestCase
    setup do
      @product = products(:sample_book)
      @variant = product_variants(:sample_book_standard)
    end

    test "resolves department and tax through product and merchandise class" do
      result = ResolveClassification.call(product: @product, variant: @variant)

      assert_equal @product.merchandise_class, result.merchandise_class
      assert_equal "Product", result.merchandise_class_source
      assert result.department.present?
      assert result.tax_category.present?
    end

    test "variant overrides win over product defaults" do
      dept = departments(:books_new)
      tax = tax_categories(:physical_book)
      @variant.update!(department: dept, tax_category: tax)

      result = ResolveClassification.call(product: @product, variant: @variant.reload)

      assert_equal dept, result.department
      assert_equal "Variant", result.department_source
      assert_equal tax, result.tax_category
      assert_equal "Variant", result.tax_category_source
    end
  end
end
