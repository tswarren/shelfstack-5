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

      test "preserves operational department fields on re-import while refreshing name" do
        Classification::Import::ReferenceData.call(organization: @organization)

        department = @organization.departments.find_by!(code: "books_new_general_trade")
        department.update!(
          name: "Admin Renamed",
          sales_revenue_gl_account_code: "9999"
        )

        Classification::Import::ReferenceData.call(organization: @organization)
        department.reload

        assert_equal "9999", department.sales_revenue_gl_account_code
        assert_equal "New General Trade", department.name
      end

      test "imports inventory adjustment reasons by kind and code" do
        Classification::Import::ReferenceData.call(organization: @organization)

        reason = @organization.inventory_adjustment_reasons.find_by!(
          adjustment_kind: "quantity_only",
          code: "physical_count_shortage"
        )
        assert_equal "Physical Count Shortage", reason.name
        assert_equal "quantity_only.physical_count_shortage", reason.qualified_code
        refute reason.requires_note?
      end
    end
  end
end
