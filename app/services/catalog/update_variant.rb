# frozen_string_literal: true

module Catalog
  class UpdateVariant < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      name description inventory_tracking_mode default_product_condition_id
      regular_price_cents department_id tax_category_id merchandise_class_id
      discountability_setting returnability_setting status sellable purchasable
      available_from available_until
    ].freeze

    def initialize(variant:, attributes:, actor:, store:)
      @variant = variant
      @attributes = attributes.stringify_keys
      @actor = actor
      @store = store
    end

    def call
      return false if @attributes.key?("sku")

      if tracking_mode_change_blocked?
        @variant.errors.add(:inventory_tracking_mode, "cannot change after inventory history exists")
        return false
      end

      ActiveRecord::Base.transaction do
        before = Administration::ChangeMetadata.snapshot(@variant, TRACKED_ATTRIBUTES)

        @variant.assign_attributes(@attributes.slice(*TRACKED_ATTRIBUTES))
        @variant.save!

        metadata = {
          "sku" => @variant.sku,
          "product_id" => @variant.product_id
        }.merge(Administration::ChangeMetadata.diff(before,
          Administration::ChangeMetadata.snapshot(@variant, TRACKED_ATTRIBUTES)))

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @variant.organization,
          store: @store,
          action: "catalog.variant.updated",
          subject: @variant,
          metadata: metadata
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    def tracking_mode_change_blocked?
      requested = @attributes["inventory_tracking_mode"]
      return false if requested.blank?
      return false if requested.to_s == @variant.inventory_tracking_mode

      StockBalance.exists?(product_variant_id: @variant.id) ||
        InventoryLedgerEntry.exists?(product_variant_id: @variant.id) ||
        InventoryReservation.exists?(product_variant_id: @variant.id) ||
        InventoryAdjustmentLine.exists?(product_variant_id: @variant.id)
    end
  end
end
