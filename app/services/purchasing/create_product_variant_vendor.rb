# frozen_string_literal: true

module Purchasing
  class CreateProductVariantVendor < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      product_variant_id vendor_id vendor_item_code vendor_identifier
      list_cost_cents discount_bps expected_unit_cost_cents
      minimum_order_quantity order_multiple returnable preferred active notes
    ].freeze
    COST_ATTRIBUTES = %w[list_cost_cents discount_bps expected_unit_cost_cents].freeze

    def initialize(product_variant_vendor:, actor:, organization:, store: nil)
      @product_variant_vendor = product_variant_vendor
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      if @store.blank?
        @product_variant_vendor.errors.add(:base, "store is required to authorize vendor-source management")
        return false
      end
      if Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "purchasing.vendor_source.manage") != :allow
        @product_variant_vendor.errors.add(:base, "not permitted to manage vendor sources")
        return false
      end

      unless cost_edit_authorized?
        COST_ATTRIBUTES.each { |attr| @product_variant_vendor.write_attribute(attr, nil) }
      end

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

    private

    def cost_edit_authorized?
      Authorization::EvaluatePermission.call(
        user: @actor, store: @store, permission_key: "purchasing.cost.view"
      ) == :allow
    end
  end
end
