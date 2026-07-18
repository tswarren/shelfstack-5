# frozen_string_literal: true

module Classification
  class UpdateReturnReason < ApplicationService
    TRACKED_ATTRIBUTES = %w[name code default_return_disposition active].freeze
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(return_reason:, attributes:, actor:, organization:)
      @return_reason = return_reason
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@return_reason, TRACKED_ATTRIBUTES)

        @return_reason.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @return_reason.save!

        metadata = {
          "code" => @return_reason.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@return_reason, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "return_reason.updated",
          subject: @return_reason,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
