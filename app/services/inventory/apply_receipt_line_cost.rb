# frozen_string_literal: true

module Inventory
  # Shared draft Receipt Line cost normalization for CreateReceipt / UpdateDraftReceipt.
  module ApplyReceiptLineCost
    module_function

    def apply!(line, vendor:)
      case line.cost_quality
      when "unknown"
        line.actual_unit_cost_cents = nil
        line.cost_quality = "unknown"
        line.cost_provenance = "unknown"
        return
      when "confirmed_zero"
        line.actual_unit_cost_cents = 0
        line.cost_quality = "confirmed_zero"
        line.cost_provenance = "confirmed_zero"
        return
      end

      if line.actual_unit_cost_cents.present? && line.cost_provenance == "manual_receipt"
        line.cost_quality = "actual" if line.cost_quality.blank?
        return
      end

      if line.actual_unit_cost_cents.present? &&
         !ResolveReceiptLineCost::AUTO_PROVENANCES.include?(line.cost_provenance.to_s)
        line.cost_provenance = "manual_receipt" if line.cost_provenance.blank?
        line.cost_quality = "actual" if line.cost_quality.blank?
        return
      end

      # Auto provenance with amount: if context still matches, keep; otherwise recompute.
      # Blank amount with auto/blank provenance: suggest.
      if line.actual_unit_cost_cents.present? &&
         ResolveReceiptLineCost::AUTO_PROVENANCES.include?(line.cost_provenance.to_s)
        suggestion = SuggestReceiptLineCost.call(
          purchase_order_line: line.purchase_order_line,
          product_variant: line.product_variant,
          vendor: vendor
        )
        if suggestion && suggestion.cost_provenance == line.cost_provenance &&
           suggestion.unit_cost_cents == line.actual_unit_cost_cents
          line.cost_quality = "estimated"
          return
        end
        # Context changed or amount drifted — recompute below.
      end

      return if line.actual_unit_cost_cents.present? && line.cost_quality == "actual"

      suggestion = SuggestReceiptLineCost.call(
        purchase_order_line: line.purchase_order_line,
        product_variant: line.product_variant,
        vendor: vendor
      )
      if suggestion.blank?
        # Context has no suggestion: clear stale auto values.
        if ResolveReceiptLineCost::AUTO_PROVENANCES.include?(line.cost_provenance.to_s) ||
           line.actual_unit_cost_cents.blank?
          line.actual_unit_cost_cents = nil if ResolveReceiptLineCost::AUTO_PROVENANCES.include?(line.cost_provenance.to_s)
          line.cost_quality = nil if ResolveReceiptLineCost::AUTO_PROVENANCES.include?(line.cost_provenance.to_s)
          line.cost_provenance = nil if ResolveReceiptLineCost::AUTO_PROVENANCES.include?(line.cost_provenance.to_s)
        end
        return
      end

      line.actual_unit_cost_cents = suggestion.unit_cost_cents
      line.cost_quality = suggestion.cost_quality
      line.cost_provenance = suggestion.cost_provenance
    end
  end
end
