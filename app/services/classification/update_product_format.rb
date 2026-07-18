# frozen_string_literal: true

module Classification
  class UpdateProductFormat < ApplicationService
    TRACKED_ATTRIBUTES = CreateProductFormat::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[code].freeze

    def initialize(product_format:, attributes:, actor:, organization:)
      @product_format = product_format
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@product_format, TRACKED_ATTRIBUTES)

        @product_format.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @product_format.save!

        metadata = {
          "code" => @product_format.code
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@product_format, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "product_format.updated",
          subject: @product_format,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
