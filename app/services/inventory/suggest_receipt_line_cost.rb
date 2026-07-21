# frozen_string_literal: true

module Inventory
  # Suggests a draft Receipt Line unit cost when the operator leaves cost blank.
  # Order matches Inventory::PostReceipt#receipt_cost_inputs: vendor-source
  # expected → list − discount → linked Purchase-Order expected.
  class SuggestReceiptLineCost < ApplicationService
    Suggestion = Data.define(:unit_cost_cents, :cost_quality, :cost_provenance)

    def initialize(purchase_order_line: nil, product_variant: nil, vendor: nil)
      @purchase_order_line = purchase_order_line
      @product_variant = product_variant || purchase_order_line&.product_variant
      @vendor = vendor || purchase_order_line&.purchase_order&.vendor
    end

    def call
      source = resolve_vendor_source
      if source&.expected_unit_cost_cents.present?
        return Suggestion.new(
          unit_cost_cents: source.expected_unit_cost_cents,
          cost_quality: "actual",
          cost_provenance: "vendor_source"
        )
      end

      if source&.list_cost_cents.present?
        discount = source.discount_bps.to_i
        estimated = Rounding.round_half_up(source.list_cost_cents.to_i * (10_000 - discount), 10_000)
        return Suggestion.new(
          unit_cost_cents: estimated,
          cost_quality: "estimated",
          cost_provenance: "vendor_list_discount"
        )
      end

      if @purchase_order_line&.expected_unit_cost_cents.present?
        return Suggestion.new(
          unit_cost_cents: @purchase_order_line.expected_unit_cost_cents,
          cost_quality: "estimated",
          cost_provenance: "purchase_order_expected"
        )
      end

      nil
    end

    private

    def resolve_vendor_source
      return @purchase_order_line.product_variant_vendor if @purchase_order_line&.product_variant_vendor.present?
      return nil if @product_variant.blank? || @vendor.blank?

      ProductVariantVendor.find_by(product_variant_id: @product_variant.id, vendor_id: @vendor.id, active: true)
    end
  end
end
