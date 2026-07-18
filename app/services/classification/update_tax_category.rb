# frozen_string_literal: true

module Classification
  class UpdateTaxCategory < ApplicationService
    TRACKED_ATTRIBUTES = %w[name code active].freeze
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(tax_category:, attributes:, actor:, organization:)
      @tax_category = tax_category
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@tax_category, TRACKED_ATTRIBUTES)

        @tax_category.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @tax_category.save!

        metadata = {
          "code" => @tax_category.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@tax_category, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "tax_category.updated",
          subject: @tax_category,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
