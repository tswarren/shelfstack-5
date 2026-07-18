# frozen_string_literal: true

require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
    @tax_category = tax_categories(:physical_book)
  end

  test "rejects hierarchy cycle" do
    parent = departments(:books_parent)
    child = departments(:books_new)

    parent.parent_department = child
    assert_not parent.valid?
    assert_includes parent.errors[:parent_department], "would create a hierarchy cycle"
  end

  test "code and department_number are readonly after create" do
    department = departments(:books_new)

    assert_raises(ActiveRecord::ReadonlyAttributeError) { department.code = "changed" }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { department.department_number = 999 }
  end

  test "default tax category must belong to same organization" do
    foreign_tax = TaxCategory.new(
      organization_id: @organization.id + 99_999,
      code: "foreign",
      name: "Foreign"
    )

    department = @organization.departments.new(
      department_number: 300,
      code: "foreign_dept",
      name: "Foreign Dept",
      postable: true,
      default_tax_category: foreign_tax,
      active: true
    )

    assert_not department.valid?
    assert_includes department.errors[:default_tax_category], "must belong to the same organization"
  end

  test "rejects non-postable when active merchandise class uses department as default" do
    department = departments(:books_new)
    department.postable = false

    assert_not department.valid?
    assert_includes department.errors[:postable],
      "cannot be false while active merchandise classes use this department as a default"
  end

  test "rejects non-postable when active merchandise class uses department as used default" do
    department = departments(:books_new)
    merchandise_classes(:fiction_primary).update!(
      default_department: nil,
      default_used_department: department
    )
    department.postable = false

    assert_not department.valid?
    assert_includes department.errors[:postable],
      "cannot be false while active merchandise classes use this department as a default"
  end
end
