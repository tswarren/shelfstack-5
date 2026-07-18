# frozen_string_literal: true

require "test_helper"

module Administration
  class CreateRoleTest < ActiveSupport::TestCase
    test "creates role with permissions and audit event" do
      organization = organizations(:acme)
      role = organization.roles.new(code: "buyer", name: "Buyer", active: true)
      permission = permissions(:store_view)

      assert_difference([ "Role.count", "RolePermission.count", "AdministrativeAuditEvent.count" ]) do
        assert CreateRole.call(
          role: role,
          permission_ids: [ permission.id ],
          actor: users(:admin),
          organization: organization,
          store: stores(:main_street)
        )
      end

      assert_equal [ permission.code ], role.permissions.pluck(:code)
      event = AdministrativeAuditEvent.order(:id).last
      assert_equal "role.created", event.action
      assert_equal [ permission.code ], event.metadata["permission_codes_added"]
    end

    test "invalid permission id does not create role" do
      organization = organizations(:acme)
      role = organization.roles.new(code: "temp", name: "Temp", active: true)

      assert_no_difference([ "Role.count", "AdministrativeAuditEvent.count" ]) do
        assert_not CreateRole.call(
          role: role,
          permission_ids: [ 999_999_999 ],
          actor: users(:admin),
          organization: organization,
          store: stores(:main_street)
        )
      end
    end
  end
end
