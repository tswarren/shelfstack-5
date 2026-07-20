# frozen_string_literal: true

require "test_helper"

class ClassificationCrudPermissionTest < ActionDispatch::IntegrationTest
  test "clerk without department manage is denied new/create" do
    post session_path, params: { username: "clerk", password: "password123" }

    get new_department_path
    assert_redirected_to root_path

    assert_no_difference "Department.count" do
      post departments_path, params: {
        department: { code: "deny_dept", name: "Denied", department_number: "9999", active: true }
      }
    end
    assert_redirected_to root_path
  end

  test "clerk without merchandise class manage is denied new" do
    post session_path, params: { username: "clerk", password: "password123" }
    get new_merchandise_class_path
    assert_redirected_to root_path
  end

  test "clerk without reason manage is denied new" do
    post session_path, params: { username: "clerk", password: "password123" }
    get new_discount_reason_path
    assert_redirected_to root_path
  end
end
