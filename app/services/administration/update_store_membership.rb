# frozen_string_literal: true

module Administration
  class UpdateStoreMembership < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      role_id active starts_on ends_on
      maximum_discount_rate maximum_discount_amount_cents
      maximum_price_override_rate maximum_cash_refund_cents
      maximum_no_receipt_return_cents maximum_paid_out_cents
      cash_variance_review_threshold_cents
    ].freeze

    IMMUTABLE_ATTRIBUTES = %w[user_id store_id].freeze

    def initialize(membership:, attributes:, actor:, organization:, store:)
      @membership = membership
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        before = ChangeMetadata.snapshot(@membership, TRACKED_ATTRIBUTES)

        @membership.assign_attributes(@attributes)
        @membership.save!

        metadata = {
          "user_id" => @membership.user_id,
          "role_id" => @membership.role_id
        }.merge(ChangeMetadata.diff(before, ChangeMetadata.snapshot(@membership, TRACKED_ATTRIBUTES)))

        RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          store: @store,
          action: "membership.updated",
          subject: @membership,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
