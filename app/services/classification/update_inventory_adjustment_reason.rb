# frozen_string_literal: true

module Classification
  class UpdateInventoryAdjustmentReason < ApplicationService
    TRACKED_ATTRIBUTES = CreateInventoryAdjustmentReason::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[code adjustment_kind].freeze

    def initialize(inventory_adjustment_reason:, attributes:, actor:, organization:)
      @inventory_adjustment_reason = inventory_adjustment_reason
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@inventory_adjustment_reason, TRACKED_ATTRIBUTES)

        @inventory_adjustment_reason.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @inventory_adjustment_reason.save!

        metadata = {
          "qualified_code" => @inventory_adjustment_reason.qualified_code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@inventory_adjustment_reason, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "inventory_adjustment_reason.updated",
          subject: @inventory_adjustment_reason,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
