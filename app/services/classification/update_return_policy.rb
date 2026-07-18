# frozen_string_literal: true

module Classification
  class UpdateReturnPolicy < ApplicationService
    TRACKED_ATTRIBUTES = %w[name code final_sale return_window_days active].freeze
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(return_policy:, attributes:, actor:, organization:)
      @return_policy = return_policy
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@return_policy, TRACKED_ATTRIBUTES)

        @return_policy.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @return_policy.save!

        metadata = {
          "code" => @return_policy.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@return_policy, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "return_policy.updated",
          subject: @return_policy,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
