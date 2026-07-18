# frozen_string_literal: true

require "test_helper"

module Classification
  module Import
    class ReferenceDataTest < ActiveSupport::TestCase
      setup do
        @organization = organizations(:acme)
      end

      test "imports tax categories and departments from export CSVs" do
        Classification::Import::ReferenceData.call(organization: @organization)

        assert_equal 20, @organization.tax_categories.count

        department_rows = CSV.read(Rails.root.join("docs/exports/departments.csv"), headers: true)
        imported_codes = @organization.departments.where(code: department_rows.map { |row| row["code"] }).pluck(:code)
        assert_equal department_rows.size, imported_codes.size

        child = @organization.departments.find_by!(code: "books_new_general_trade")
        parent = @organization.departments.find_by!(code: "books")
        assert_equal parent, child.parent_department
        assert_equal @organization.tax_categories.find_by!(code: "physical_book"), child.default_tax_category
      end

      test "does not reactivate deactivated records on re-import" do
        Classification::Import::ReferenceData.call(organization: @organization)

        tax_category = @organization.tax_categories.find_by!(code: "physical_book")
        tax_category.update!(active: false)

        Classification::Import::ReferenceData.call(organization: @organization)

        assert_not tax_category.reload.active?
      end
    end
  end
end
