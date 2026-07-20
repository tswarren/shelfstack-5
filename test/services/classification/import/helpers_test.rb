# frozen_string_literal: true

require "test_helper"

module Classification
  module Import
    class HelpersTest < ActiveSupport::TestCase
      include Helpers

      test "truthy and blank_value parsing" do
        assert truthy?("TRUE")
        assert truthy?(" true ")
        refute truthy?("FALSE")
        refute truthy?("yes")

        assert blank_value?(nil)
        assert blank_value?("  ")
        refute blank_value?("FALSE")
      end

      test "assign_active_preserving_deactivation keeps inactive records inactive" do
        record = TaxCategory.new(active: true)
        assign_active_preserving_deactivation(record, "FALSE")
        assert_equal false, record.active

        existing = tax_categories(:physical_book)
        existing.update!(active: false)
        assign_active_preserving_deactivation(existing, "TRUE")
        assert_equal false, existing.active

        existing.update!(active: true)
        assign_active_preserving_deactivation(existing, "FALSE")
        assert_equal false, existing.active
      end

      test "load_csv reads docs exports" do
        rows = load_csv("tax_categories.csv")
        assert rows.headers.include?("code")
        assert rows.size.positive?
      end
    end
  end
end
