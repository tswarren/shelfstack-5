# frozen_string_literal: true

module Classification
  class UpdateProductCondition < ApplicationService
    TRACKED_ATTRIBUTES = CreateProductCondition::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(product_condition:, attributes:, actor:, organization:)
      @product_condition = product_condition
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@product_condition, TRACKED_ATTRIBUTES)

        @product_condition.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @product_condition.save!

        metadata = {
          "code" => @product_condition.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@product_condition, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "product_condition.updated",
          subject: @product_condition,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
