# frozen_string_literal: true

require "test_helper"

module Classification
  class CreateTaxCategoryTest < ActiveSupport::TestCase
    test "creates tax category and writes audit" do
      category = organizations(:acme).tax_categories.new(code: "services", name: "Services", active: true)

      assert_difference("AdministrativeAuditEvent.count") do
        assert CreateTaxCategory.call(
          tax_category: category,
          actor: users(:admin),
          organization: organizations(:acme)
        )
      end

      assert category.persisted?
      assert_equal "tax_category.created", AdministrativeAuditEvent.order(:id).last.action
    end

    test "returns false without audit when code collides" do
      category = organizations(:acme).tax_categories.new(
        code: tax_categories(:physical_book).code, name: "Dup", active: true
      )

      assert_no_difference("AdministrativeAuditEvent.count") do
        refute CreateTaxCategory.call(
          tax_category: category,
          actor: users(:admin),
          organization: organizations(:acme)
        )
      end
    end
  end
end
