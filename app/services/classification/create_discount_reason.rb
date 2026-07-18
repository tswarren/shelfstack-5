# frozen_string_literal: true

module Classification
  class CreateDiscountReason < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      name code default_calculation_method default_rate_bps default_amount_cents
      maximum_rate_bps requires_approval resulting_return_policy_id active
    ].freeze

    def initialize(discount_reason:, actor:, organization:)
      @discount_reason = discount_reason
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @discount_reason.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "discount_reason.created",
          subject: @discount_reason,
          metadata: {
            "code" => @discount_reason.code,
            "after" => Administration::ChangeMetadata.snapshot(@discount_reason, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
