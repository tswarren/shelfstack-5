# frozen_string_literal: true

module Purchasing
  class CreateProductVariantVendor < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      product_variant_id vendor_id vendor_item_code vendor_identifier
      list_cost_cents discount_bps expected_unit_cost_cents
      minimum_order_quantity order_multiple returnable preferred active notes
    ].freeze

    def initialize(product_variant_vendor:, actor:, organization:)
      @product_variant_vendor = product_variant_vendor
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @product_variant_vendor.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "product_variant_vendor.created",
          subject: @product_variant_vendor,
          metadata: {
            "vendor_id" => @product_variant_vendor.vendor_id,
            "product_variant_id" => @product_variant_vendor.product_variant_id,
            "after" => Administration::ChangeMetadata.snapshot(@product_variant_vendor, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
