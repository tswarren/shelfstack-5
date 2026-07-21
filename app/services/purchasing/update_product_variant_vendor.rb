# frozen_string_literal: true

module Purchasing
  class UpdateProductVariantVendor < ApplicationService
    TRACKED_ATTRIBUTES = CreateProductVariantVendor::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[product_variant_id vendor_id].freeze

    def initialize(product_variant_vendor:, attributes:, actor:, organization:)
      @product_variant_vendor = product_variant_vendor
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@product_variant_vendor, TRACKED_ATTRIBUTES)

        @product_variant_vendor.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @product_variant_vendor.save!

        metadata = {
          "vendor_id" => @product_variant_vendor.vendor_id,
          "product_variant_id" => @product_variant_vendor.product_variant_id
        }.merge(
          Administration::ChangeMetadata.diff(
            before,
            Administration::ChangeMetadata.snapshot(@product_variant_vendor, TRACKED_ATTRIBUTES)
          )
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "product_variant_vendor.updated",
          subject: @product_variant_vendor,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
