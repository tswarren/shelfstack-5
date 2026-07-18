# frozen_string_literal: true

require "test_helper"

module Administration
  class UpdateRoleTest < ActiveSupport::TestCase
    setup do
      @role = roles(:associate)
      @actor = users(:admin)
      @organization = organizations(:acme)
      @store = stores(:main_street)
      @existing_permission = permissions(:store_view)
      RolePermission.find_or_create_by!(role: @role, permission: @existing_permission)
    end

    test "syncs permissions and writes audit metadata in one transaction" do
      keep = permissions(:store_view)
      add = permissions(:store_manage)

      assert_difference("AdministrativeAuditEvent.count") do
        assert UpdateRole.call(
          role: @role,
          attributes: { name: "Floor Associate" },
          permission_ids: [ keep.id, add.id ],
          actor: @actor,
          organization: @organization,
          store: @store
        )
      end

      @role.reload
      assert_equal "Floor Associate", @role.name
      assert_equal [ keep.code, add.code ].sort, @role.permissions.pluck(:code).sort

      event = AdministrativeAuditEvent.order(:id).last
      assert_equal "role.updated", event.action
      assert_includes event.metadata["permission_codes_added"], add.code
      assert_equal "Floor Associate", event.metadata.dig("after", "name")
    end

    test "invalid permission id rolls back role and assignment changes" do
      original_name = @role.name
      original_ids = @role.permission_ids.sort

      assert_no_difference("AdministrativeAuditEvent.count") do
        assert_not UpdateRole.call(
          role: @role,
          attributes: { name: "Should Not Persist" },
          permission_ids: [ @existing_permission.id, 999_999_999 ],
          actor: @actor,
          organization: @organization,
          store: @store
        )
      end

      @role.reload
      assert_equal original_name, @role.name
      assert_equal original_ids, @role.permission_ids.sort
      assert @role.errors[:base].any?
    end

    test "nonnumeric permission ids are rejected and do not clear assignments" do
      original_ids = @role.permission_ids.sort

      assert_not UpdateRole.call(
        role: @role,
        attributes: { name: @role.name },
        permission_ids: [ "abc" ],
        actor: @actor,
        organization: @organization,
        store: @store
      )

      assert_equal original_ids, @role.reload.permission_ids.sort
    end

    test "mixed valid and invalid permission ids reject the whole request" do
      original_ids = @role.permission_ids.sort

      assert_not UpdateRole.call(
        role: @role,
        attributes: { name: @role.name },
        permission_ids: [ @existing_permission.id, "abc", -1, "" ],
        actor: @actor,
        organization: @organization,
        store: @store
      )

      assert_equal original_ids, @role.reload.permission_ids.sort
    end


    test "audit failure rolls back permission sync" do
      keep = permissions(:store_view)
      add = permissions(:user_view)
      original_ids = @role.permission_ids.sort
      original_name = @role.name

      raiser = ->(*) { raise ActiveRecord::RecordInvalid, AdministrativeAuditEvent.new }
      RecordAuditEvent.singleton_class.alias_method :__original_call, :call
      RecordAuditEvent.define_singleton_method(:call, raiser)
      begin
        assert_not UpdateRole.call(
          role: @role,
          attributes: { name: "Audited Fail" },
          permission_ids: [ keep.id, add.id ],
          actor: @actor,
          organization: @organization,
          store: @store
        )
      ensure
        RecordAuditEvent.singleton_class.alias_method :call, :__original_call
        RecordAuditEvent.singleton_class.remove_method :__original_call
      end

      @role.reload
      assert_equal original_ids, @role.permission_ids.sort
      assert_equal original_name, @role.name
    end
  end
end
