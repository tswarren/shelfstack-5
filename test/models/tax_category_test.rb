# frozen_string_literal: true

require "test_helper"

class TaxCategoryTest < ActiveSupport::TestCase
  test "code is unique within an organization" do
    duplicate = TaxCategory.new(
      organization: organizations(:acme),
      code: tax_categories(:physical_book).code,
      name: "Duplicate",
      active: true
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "code is readonly after create" do
    category = tax_categories(:physical_book)
    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      category.code = "changed"
    end
  end
end
