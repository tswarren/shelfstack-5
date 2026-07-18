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
  end
end
