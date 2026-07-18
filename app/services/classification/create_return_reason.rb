# frozen_string_literal: true

module Classification
  class CreateReturnReason < ApplicationService
    TRACKED_ATTRIBUTES = %w[name code default_return_disposition active].freeze

    def initialize(return_reason:, actor:, organization:)
      @return_reason = return_reason
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @return_reason.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "return_reason.created",
          subject: @return_reason,
          metadata: {
            "code" => @return_reason.code,
            "after" => Administration::ChangeMetadata.snapshot(@return_reason, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
