# frozen_string_literal: true

module Purchasing
  class UpdateProductVariantVendor < ApplicationService
    TRACKED_ATTRIBUTES = CreateProductVariantVendor::TRACKED_ATTRIBUTES
    IMMUTABLE_ATTRIBUTES = %w[product_variant_id vendor_id].freeze

    def initialize(product_variant_vendor:, attributes:, actor:, organization:, store: nil)
      @product_variant_vendor = product_variant_vendor
      @attributes = attributes.stringify_keys.except(*IMMUTABLE_ATTRIBUTES)
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
