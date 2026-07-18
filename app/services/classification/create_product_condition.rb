# frozen_string_literal: true

module Classification
  class CreateProductCondition < ApplicationService
    TRACKED_ATTRIBUTES = %w[name code description position active].freeze

    def initialize(product_condition:, actor:, organization:)
      @product_condition = product_condition
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @product_condition.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "product_condition.created",
          subject: @product_condition,
          metadata: {
            "code" => @product_condition.code,
            "after" => Administration::ChangeMetadata.snapshot(@product_condition, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
