# frozen_string_literal: true

module Administration
  # Explicitly grants every catalog permission to the administrator role.
  # Additive only; does not remove existing assignments. Audited.
  class SyncAdministratorPermissions < ApplicationService
    def initialize(role:, actor:, organization:, store:)
      @role = role
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      unless @role.code == "administrator"
        raise ArgumentError, "SyncAdministratorPermissions only applies to the administrator role"
      end

      ActiveRecord::Base.transaction do
        previous_codes = @role.permissions.pluck(:code).sort
        Permission.find_each do |permission|
          @role.role_permissions.find_or_create_by!(permission_id: permission.id)
        end

        added = @role.permissions.reload.pluck(:code).sort - previous_codes
        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "role.permissions_synced",
          subject: @role,
          metadata: {
            "code" => @role.code,
            "permission_codes_added" => added,
            "permission_codes_removed" => []
          }
        )
      end

      true
    end
  end
end
