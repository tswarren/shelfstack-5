# frozen_string_literal: true

module Classification
  class CreateInventoryAdjustmentReason < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      adjustment_kind code name description requires_note active position
    ].freeze

    def initialize(inventory_adjustment_reason:, actor:, organization:)
      @inventory_adjustment_reason = inventory_adjustment_reason
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @inventory_adjustment_reason.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "inventory_adjustment_reason.created",
          subject: @inventory_adjustment_reason,
          metadata: {
            "qualified_code" => @inventory_adjustment_reason.qualified_code,
            "after" => Administration::ChangeMetadata.snapshot(@inventory_adjustment_reason, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
