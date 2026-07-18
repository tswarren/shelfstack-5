# frozen_string_literal: true

require "test_helper"

module Administration
  class SyncAdministratorPermissionsTest < ActiveSupport::TestCase
    test "adds missing catalog permissions and writes audit" do
      role = roles(:administrator)
      permission = permissions(:audit_view)
      RolePermission.where(role: role, permission: permission).delete_all

      assert_difference("AdministrativeAuditEvent.count") do
        assert SyncAdministratorPermissions.call(
          role: role,
          actor: users(:admin),
          organization: organizations(:acme),
          store: stores(:main_street)
        )
      end

      assert RolePermission.exists?(role: role, permission: permission)
      event = AdministrativeAuditEvent.order(:id).last
      assert_equal "role.permissions_synced", event.action
      assert_includes event.metadata["permission_codes_added"], permission.code
    end
  end
end
