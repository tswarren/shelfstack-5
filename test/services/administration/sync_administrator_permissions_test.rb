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

    test "fills null administrator membership authority limits without overwriting configured values" do
      membership = store_memberships(:admin_main_street)
      membership.update!(
        maximum_discount_rate: nil,
        maximum_discount_amount_cents: nil,
        maximum_cash_refund_cents: nil
      )
      configured_override_rate = membership.maximum_price_override_rate

      SyncAdministratorPermissions.call(
        role: roles(:administrator),
        actor: users(:admin),
        organization: organizations(:acme),
        store: stores(:main_street)
      )

      membership.reload
      assert_equal BigDecimal("1"), membership.maximum_discount_rate
      assert_equal 2_147_483_647, membership.maximum_discount_amount_cents
      assert_equal configured_override_rate, membership.maximum_price_override_rate
    end
  end
end
