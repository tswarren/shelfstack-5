# frozen_string_literal: true

require "test_helper"

module Classification
  class UpdateDepartmentTest < ActiveSupport::TestCase
    setup do
      @department = departments(:books_new)
      @actor = users(:admin)
      @organization = organizations(:acme)
    end

    test "updates mutable fields while ignoring code and department_number" do
      original_code = @department.code
      original_number = @department.department_number

      assert Classification::UpdateDepartment.call(
        department: @department,
        attributes: {
          "code" => "changed_code",
          "department_number" => 9999,
          "name" => "Renamed Books"
        },
        actor: @actor,
        organization: @organization
      )

      @department.reload
      assert_equal "Renamed Books", @department.name
      assert_equal original_code, @department.code
      assert_equal original_number, @department.department_number
    end

    test "rejects postable false while referenced as default_department" do
      assert merchandise_classes(:fiction_primary).default_department_id == @department.id

      assert_not Classification::UpdateDepartment.call(
        department: @department,
        attributes: { "postable" => false },
        actor: @actor,
        organization: @organization
      )

      assert_includes @department.errors[:postable],
        "cannot be false while active merchandise classes use this department as a default"
      assert @department.reload.postable?
    end

    test "rejects postable false while referenced as default_used_department" do
      used_department = Department.create!(
        organization: @organization,
        parent_department: departments(:books_parent),
        department_number: "111",
        code: "books_used_general_trade",
        name: "Used General Trade",
        postable: true,
        default_tax_category: tax_categories(:physical_book),
        active: true
      )
      merchandise_classes(:fiction_primary).update!(default_used_department: used_department)

      assert_not Classification::UpdateDepartment.call(
        department: used_department,
        attributes: { "postable" => false },
        actor: @actor,
        organization: @organization
      )

      assert_includes used_department.errors[:postable],
        "cannot be false while active merchandise classes use this department as a default"
      assert used_department.reload.postable?
    end


    test "allows postable false when no active merchandise class defaults reference it" do
      unreferenced = Department.create!(
        organization: @organization,
        parent_department: departments(:books_parent),
        department_number: "112",
        code: "books_unreferenced",
        name: "Unreferenced Books",
        postable: true,
        default_tax_category: tax_categories(:physical_book),
        active: true
      )

      assert Classification::UpdateDepartment.call(
        department: unreferenced,
        attributes: { "postable" => false },
        actor: @actor,
        organization: @organization
      )

      assert_not unreferenced.reload.postable?
    end

    test "allows postable false after merchandise class defaults are cleared" do
      merchandise_class = merchandise_classes(:fiction_primary)
      merchandise_class.update!(default_department: nil, default_used_department: nil)

      assert Classification::UpdateDepartment.call(
        department: @department,
        attributes: { "postable" => false },
        actor: @actor,
        organization: @organization
      )

      assert_not @department.reload.postable?
    end
  end
end
