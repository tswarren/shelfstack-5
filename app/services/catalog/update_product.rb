# frozen_string_literal: true

module Catalog
  class UpdateProduct < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      name subtitle description product_type product_format_id merchandise_class_id
      default_department_id default_tax_category_id list_price_cents status sellable
      available_from available_until publisher_or_manufacturer_name imprint_or_brand_name
      alternate_identifier
    ].freeze

    def initialize(product:, attributes:, actor:, store:)
      @product = product
      @attributes = attributes.stringify_keys
      @actor = actor
      @store = store
    end

    def call
      return false if @attributes.key?("identifier")

      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@product, TRACKED_ATTRIBUTES)

        @product.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @product.save!

        metadata = {
          "identifier" => @product.identifier
        }.merge(Administration::ChangeMetadata.diff(before,
          Administration::ChangeMetadata.snapshot(@product, TRACKED_ATTRIBUTES)))

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @product.organization,
          store: @store,
          action: "catalog.product.updated",
          subject: @product,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
