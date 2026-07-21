# frozen_string_literal: true

module Inventory
  # Shared draft Receipt Line cost normalization for CreateReceipt / UpdateDraftReceipt.
  module ApplyReceiptLineCost
    module_function

    def apply!(line, vendor:)
      normalize_inconsistent_submitted_tuple!(line)

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
        line.cost_quality = line.cost_quality.presence_in(%w[actual estimated]) || "actual"
        return
      end

      if line.actual_unit_cost_cents.present? &&
         !ResolveReceiptLineCost::AUTO_PROVENANCES.include?(line.cost_provenance.to_s)
        line.cost_provenance = "manual_receipt"
        line.cost_quality = line.cost_quality.presence_in(%w[actual estimated]) || "actual"
        return
      end

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
      end

      return if line.actual_unit_cost_cents.present? && line.cost_quality == "actual" &&
                line.cost_provenance == "manual_receipt"

      suggestion = SuggestReceiptLineCost.call(
        purchase_order_line: line.purchase_order_line,
        product_variant: line.product_variant,
        vendor: vendor
      )
      if suggestion.blank?
        if ResolveReceiptLineCost::AUTO_PROVENANCES.include?(line.cost_provenance.to_s)
          line.actual_unit_cost_cents = nil
          line.cost_quality = nil
          line.cost_provenance = nil
        end
        return
      end

      line.actual_unit_cost_cents = suggestion.unit_cost_cents
      line.cost_quality = suggestion.cost_quality
      line.cost_provenance = suggestion.cost_provenance
    end

    def normalize_inconsistent_submitted_tuple!(line)
      # Confirmed-zero provenance with a non-zero amount is not a confirmation of zero.
      if line.cost_provenance == "confirmed_zero" && line.cost_quality != "confirmed_zero"
        line.cost_provenance = nil
      end
      if line.cost_quality == "confirmed_zero"
        line.actual_unit_cost_cents = 0
        line.cost_provenance = "confirmed_zero"
      end
      if line.cost_quality == "unknown"
        line.actual_unit_cost_cents = nil
        line.cost_provenance = "unknown"
      end
      if line.cost_provenance == "unknown" && line.cost_quality != "unknown"
        line.cost_provenance = nil
      end
    end
    private_class_method :normalize_inconsistent_submitted_tuple!
  end
end
