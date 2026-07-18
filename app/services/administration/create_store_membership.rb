# frozen_string_literal: true

module Administration
  class CreateStoreMembership < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      user_id role_id active starts_on ends_on
      maximum_discount_rate maximum_discount_amount_cents
      maximum_price_override_rate maximum_cash_refund_cents
      maximum_no_receipt_return_cents maximum_paid_out_cents
      cash_variance_review_threshold_cents
    ].freeze

    def initialize(membership:, actor:, organization:, store:)
      @membership = membership
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @membership.save!

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "membership.created",
          subject: @membership,
          metadata: {
            "user_id" => @membership.user_id,
            "role_id" => @membership.role_id,
            "after" => ChangeMetadata.snapshot(@membership, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
