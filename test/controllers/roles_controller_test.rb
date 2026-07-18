# frozen_string_literal: true

require "test_helper"

class RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_path, params: { username: "admin", password: "password123" }
  end

  test "updates role permissions and writes audit" do
    role = roles(:associate)
    keep = permissions(:store_view)
    add = permissions(:membership_manage)
    RolePermission.find_or_create_by!(role: role, permission: keep)

    assert_difference("AdministrativeAuditEvent.count") do
      patch role_path(role), params: {
        role: { name: role.name, code: role.code, active: true },
        permission_ids: [ keep.id, add.id ]
      }
    end

    assert_redirected_to role_path(role)
    assert_equal [ keep.code, add.code ].sort, role.reload.permissions.pluck(:code).sort
  end

  test "invalid permission id preserves existing assignments" do
    role = roles(:associate)
    keep = permissions(:store_view)
    RolePermission.find_or_create_by!(role: role, permission: keep)
    original_ids = role.permission_ids.sort

    patch role_path(role), params: {
      role: { name: "Broken Sync", code: role.code, active: true },
      permission_ids: [ keep.id, 999_999_999 ]
    }

    assert_response :unprocessable_entity
    assert_equal original_ids, role.reload.permission_ids.sort
    assert_equal "associate", role.code
    assert_not_equal "Broken Sync", role.name
  end

  test "denies clerk without role manage permission" do
    delete session_path
    post session_path, params: { username: "clerk", password: "password123" }
    get roles_path
    assert_redirected_to root_path
  end
end
