# frozen_string_literal: true

module Administration
  class UpdateRole < ApplicationService
    TRACKED_ATTRIBUTES = %w[code name description active].freeze

    def initialize(role:, attributes:, permission_ids:, actor:, organization:, store:)
      @role = role
      @attributes = attributes
      @permission_ids = permission_ids
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        permissions = resolve_permissions!
        before = ChangeMetadata.snapshot(@role, TRACKED_ATTRIBUTES)
        previous_codes = @role.permissions.pluck(:code).sort

        @role.assign_attributes(@attributes)
        @role.save!

        sync_permissions!(permissions)

        new_codes = permissions.map(&:code).sort
        metadata = {
          "code" => @role.code,
          "permission_codes_added" => new_codes - previous_codes,
          "permission_codes_removed" => previous_codes - new_codes
        }.merge(ChangeMetadata.diff(before, ChangeMetadata.snapshot(@role, TRACKED_ATTRIBUTES)))

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "role.updated",
          subject: @role,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    def resolve_permissions!
      selected_ids = Array(@permission_ids).map(&:to_i).uniq.reject(&:zero?)
      permissions = Permission.where(id: selected_ids).to_a
      if permissions.size != selected_ids.size
        @role.errors.add(:base, "One or more permission IDs are invalid")
        raise ActiveRecord::RecordInvalid, @role
      end

      permissions
    end

    def sync_permissions!(permissions)
      selected_ids = permissions.map(&:id)
      @role.role_permissions.where.not(permission_id: selected_ids).find_each(&:destroy!)
      selected_ids.each do |permission_id|
        @role.role_permissions.find_or_create_by!(permission_id: permission_id)
      end
    end
  end
end
