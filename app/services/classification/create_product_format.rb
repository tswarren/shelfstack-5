# frozen_string_literal: true

module Classification
  class CreateProductFormat < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      name code short_code format_family default_inventory_tracking_mode active
    ].freeze

    def initialize(product_format:, actor:, organization:)
      @product_format = product_format
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @product_format.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "product_format.created",
          subject: @product_format,
          metadata: {
            "code" => @product_format.code,
            "after" => Administration::ChangeMetadata.snapshot(@product_format, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
