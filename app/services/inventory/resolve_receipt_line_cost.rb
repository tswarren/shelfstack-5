# frozen_string_literal: true

module Inventory
  # Resolves Receipt Line unit cost for draft suggestions and posting.
  # Linked lines prefer PO snapshots over current Vendor Source data.
  # Non-explicit defaults are always estimated (ledger configured_estimate).
  class ResolveReceiptLineCost < ApplicationService
    AUTO_PROVENANCES = %w[
      purchase_order_expected
      purchase_order_list_discount
      vendor_source_expected
      vendor_list_discount
    ].freeze

    CONTROLLED_PROVENANCES = (
      AUTO_PROVENANCES + %w[manual_receipt unknown confirmed_zero]
    ).freeze

    Result = Data.define(
      :unit_cost_cents, :cost_quality, :cost_provenance, :ledger_cost_method, :ledger_cost_quality
    )

    def initialize(receipt_line: nil, purchase_order_line: nil, product_variant: nil, vendor: nil, suggest_only: false)
      @receipt_line = receipt_line
      @purchase_order_line = purchase_order_line || receipt_line&.purchase_order_line
      @product_variant = product_variant || receipt_line&.product_variant || @purchase_order_line&.product_variant
      @vendor = vendor || receipt_line&.receipt&.vendor || @purchase_order_line&.purchase_order&.vendor
      @suggest_only = suggest_only
    end

    def call
      unless @suggest_only
        explicit = resolve_explicit_line_cost
        return explicit if explicit
      end

      resolve_estimated_fallback || unknown_result
    end

    private

    def resolve_explicit_line_cost
      line = @receipt_line
      return nil if line.blank?

      case line.cost_quality
      when "unknown"
        return Result.new(
          unit_cost_cents: nil,
          cost_quality: "unknown",
          cost_provenance: "unknown",
          ledger_cost_method: "unknown",
          ledger_cost_quality: "unknown"
        )
      when "confirmed_zero"
        return Result.new(
          unit_cost_cents: 0,
          cost_quality: "confirmed_zero",
          cost_provenance: "confirmed_zero",
          ledger_cost_method: "explicit",
          ledger_cost_quality: "actual"
        )
      end

      return nil if line.actual_unit_cost_cents.blank?

      if line.cost_quality == "estimated" || AUTO_PROVENANCES.include?(line.cost_provenance.to_s)
        return Result.new(
          unit_cost_cents: line.actual_unit_cost_cents,
          cost_quality: "estimated",
          cost_provenance: line.cost_provenance.presence || "manual_receipt",
          ledger_cost_method: "configured_estimate",
          ledger_cost_quality: "estimated"
        )
      end

      Result.new(
        unit_cost_cents: line.actual_unit_cost_cents,
        cost_quality: "actual",
        cost_provenance: line.cost_provenance.presence || "manual_receipt",
        ledger_cost_method: "explicit",
        ledger_cost_quality: "actual"
      )
    end

    def resolve_estimated_fallback
      po_line = @purchase_order_line
      if po_line.present?
        if po_line.expected_unit_cost_cents.present?
          return estimated(
            po_line.expected_unit_cost_cents,
            "purchase_order_expected"
          )
        end
        if po_line.list_cost_cents.present?
          return estimated(
            list_minus_discount(po_line.list_cost_cents, po_line.discount_bps),
            "purchase_order_list_discount"
          )
        end
      end

      source = resolve_vendor_source
      if source&.expected_unit_cost_cents.present?
        return estimated(source.expected_unit_cost_cents, "vendor_source_expected")
      end
      if source&.list_cost_cents.present?
        return estimated(
          list_minus_discount(source.list_cost_cents, source.discount_bps),
          "vendor_list_discount"
        )
      end

      nil
    end

    def resolve_vendor_source
      return po_line_vendor_source if @purchase_order_line.present?
      return nil if @product_variant.blank? || @vendor.blank?

      ProductVariantVendor.find_by(
        product_variant_id: @product_variant.id,
        vendor_id: @vendor.id,
        active: true
      )
    end

    def po_line_vendor_source
      source = @purchase_order_line.product_variant_vendor
      return source if source.present?
      return nil if @product_variant.blank? || @vendor.blank?

      ProductVariantVendor.find_by(
        product_variant_id: @product_variant.id,
        vendor_id: @vendor.id,
        active: true
      )
    end

    def list_minus_discount(list_cost_cents, discount_bps)
      Rounding.round_half_up(list_cost_cents.to_i * (10_000 - discount_bps.to_i), 10_000)
    end

    def estimated(unit_cost_cents, provenance)
      Result.new(
        unit_cost_cents: unit_cost_cents,
        cost_quality: "estimated",
        cost_provenance: provenance,
        ledger_cost_method: "configured_estimate",
        ledger_cost_quality: "estimated"
      )
    end

    def unknown_result
      Result.new(
        unit_cost_cents: nil,
        cost_quality: "unknown",
        cost_provenance: "unknown",
        ledger_cost_method: "unknown",
        ledger_cost_quality: "unknown"
      )
    end
  end
end
