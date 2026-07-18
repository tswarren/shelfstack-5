# frozen_string_literal: true

module Classification
  class CreateReturnPolicy < ApplicationService
    TRACKED_ATTRIBUTES = %w[name code final_sale return_window_days active].freeze

    def initialize(return_policy:, actor:, organization:)
      @return_policy = return_policy
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @return_policy.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "return_policy.created",
          subject: @return_policy,
          metadata: {
            "code" => @return_policy.code,
            "after" => Administration::ChangeMetadata.snapshot(@return_policy, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
