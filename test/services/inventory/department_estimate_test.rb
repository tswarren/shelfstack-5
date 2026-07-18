# frozen_string_literal: true

require "test_helper"

module Inventory
  class DepartmentEstimateTest < ActiveSupport::TestCase
    test "calculates estimate from variant department margin and price" do
      department = departments(:books_new)
      department.update!(default_cost_estimation_margin_bps: 2500)
      variant = product_variants(:sample_book_standard)
      variant.update!(department: department, regular_price_cents: 1000)

      result = DepartmentEstimate.call(product_variant: variant)

      assert result.available
      assert_equal 750, result.unit_cost_cents
      assert_equal department, result.department
      assert_equal 2500, result.margin_bps
    end

    test "unavailable when margin missing" do
      department = departments(:books_new)
      department.update!(default_cost_estimation_margin_bps: nil)
      variant = product_variants(:sample_book_standard)
      variant.update!(department: department, regular_price_cents: 1000)

      result = DepartmentEstimate.call(product_variant: variant)
      refute result.available
    end
  end
end
