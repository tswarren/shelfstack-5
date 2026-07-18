# frozen_string_literal: true

module Classification
  class CreateTaxCategory < ApplicationService
    TRACKED_ATTRIBUTES = %w[name code active].freeze

    def initialize(tax_category:, actor:, organization:)
      @tax_category = tax_category
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @tax_category.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "tax_category.created",
          subject: @tax_category,
          metadata: {
            "code" => @tax_category.code,
            "after" => Administration::ChangeMetadata.snapshot(@tax_category, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
