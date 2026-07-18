# frozen_string_literal: true

module Classification
  class UpdateDiscountReason < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      name code default_calculation_method default_rate_bps default_amount_cents
      maximum_rate_bps requires_approval resulting_return_policy_id active
    ].freeze
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(discount_reason:, attributes:, actor:, organization:)
      @discount_reason = discount_reason
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@discount_reason, TRACKED_ATTRIBUTES)

        @discount_reason.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @discount_reason.save!

        metadata = {
          "code" => @discount_reason.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@discount_reason, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "discount_reason.updated",
          subject: @discount_reason,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
