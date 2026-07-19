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

        # OD-013 interim: permissions alone do not authorize numeric POS actions.
        # Fill unconfigured (null) authority overrides on administrator memberships.
        authority_filled = []
        StoreMembership.where(role_id: @role.id).find_each do |membership|
          filled = Authorization::AuthorityLimits.apply_administrator_defaults!(membership)
          authority_filled.concat(filled.map(&:to_s)) if filled.any?
        end

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "role.permissions_synced",
          subject: @role,
          metadata: {
            "code" => @role.code,
            "permission_codes_added" => added,
            "permission_codes_removed" => [],
            "authority_limits_filled" => authority_filled.uniq
          }
        )
      end

      true
    end
  end
end
