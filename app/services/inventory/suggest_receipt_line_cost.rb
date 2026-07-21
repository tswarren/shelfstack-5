# frozen_string_literal: true

module Inventory
  # Draft-form cost suggestion. Delegates to ResolveReceiptLineCost with
  # suggest_only so explicit line values are ignored while composing defaults.
  class SuggestReceiptLineCost < ApplicationService
    Suggestion = Data.define(:unit_cost_cents, :cost_quality, :cost_provenance, :ledger_cost_method)

    def initialize(purchase_order_line: nil, product_variant: nil, vendor: nil, receipt_line: nil)
      @purchase_order_line = purchase_order_line
      @product_variant = product_variant
      @vendor = vendor
      @receipt_line = receipt_line
    end

    def call
      resolved = ResolveReceiptLineCost.call(
        receipt_line: @receipt_line,
        purchase_order_line: @purchase_order_line,
        product_variant: @product_variant,
        vendor: @vendor,
        suggest_only: true
      )
      return nil if resolved.unit_cost_cents.nil? && resolved.cost_quality == "unknown"

      Suggestion.new(
        unit_cost_cents: resolved.unit_cost_cents,
        cost_quality: resolved.cost_quality,
        cost_provenance: resolved.cost_provenance,
        ledger_cost_method: resolved.ledger_cost_method
      )
    end
  end
end
