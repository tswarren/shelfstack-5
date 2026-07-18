# frozen_string_literal: true

module Classification
  class UpdateDepartment < ApplicationService
    TRACKED_ATTRIBUTES = CreateDepartment::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[code department_number].freeze

    def initialize(department:, attributes:, actor:, organization:)
      @department = department
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@department, TRACKED_ATTRIBUTES)

        @department.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @department.save!

        metadata = {
          "code" => @department.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@department, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "department.updated",
          subject: @department,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
