# frozen_string_literal: true

module Pos
  # Builds fingerprints and presentation copy for pending approval actions.
  module ApprovalInterrupt
    module_function

    def price_override_fingerprint(pos_line_item:, requested_unit_price_cents:, reason:)
      Digest::SHA256.hexdigest(
        [
          "price_override",
          pos_line_item.id,
          pos_line_item.unit_price_cents,
          requested_unit_price_cents.to_i,
          reason.to_s.strip
        ].join("|")
      )
    end

    def price_override_presentation(pos_line_item:, requested_unit_price_cents:)
      current = pos_line_item.unit_price_cents
      requested = requested_unit_price_cents.to_i
      PendingApprovalAction::Presentation.new(
        title: "Approval required",
        action_summary: "Price override on “#{pos_line_item.effective_description}”",
        boundary: "Your authority is insufficient for this price override.",
        material_values: format(
          "Current %s → Requested %s · Difference %s",
          money(current),
          money(requested),
          money((current - requested).abs)
        ),
        effect: "Line unit price becomes #{money(requested)} for this transaction only."
      )
    end

    def discount_fingerprint(pos_transaction:, scope:, pos_line_item_id:, method:, rate_bps:, amount_cents:, reason:)
      Digest::SHA256.hexdigest(
        [ "discount", pos_transaction.id, scope, pos_line_item_id, method, rate_bps, amount_cents, reason.to_s.strip ].join("|")
      )
    end

    def discount_presentation(scope:, description:, method:, rate_bps:, amount_cents:)
      detail = case method.to_s
      when "percentage" then "#{BigDecimal(rate_bps.to_i) / 100}% off"
      when "fixed_price" then "fixed price #{money(amount_cents)}"
      else "amount #{money(amount_cents)}"
      end
      PendingApprovalAction::Presentation.new(
        title: "Approval required",
        action_summary: "#{scope.to_s.capitalize} discount#{description.present? ? " on “#{description}”" : ""}",
        boundary: "Your authority is insufficient for this discount.",
        material_values: detail,
        effect: "The discount will apply to the open transaction after approval."
      )
    end

    def tax_override_fingerprint(pos_line_item:, tax_category_id:, reason:)
      Digest::SHA256.hexdigest(
        [ "tax_override", pos_line_item.id, tax_category_id, reason.to_s.strip ].join("|")
      )
    end

    def tax_override_presentation(pos_line_item:, tax_category_name:)
      PendingApprovalAction::Presentation.new(
        title: "Approval required",
        action_summary: "Tax category override on “#{pos_line_item.effective_description}”",
        boundary: "Your authority is insufficient for this tax override.",
        material_values: "Requested tax category: #{tax_category_name}",
        effect: "Tax classification changes for this line after approval."
      )
    end

    def cash_movement_fingerprint(pos_session:, cash_movement_type_id:, amount_cents:, reason:)
      Digest::SHA256.hexdigest(
        [ "cash_movement", pos_session.id, cash_movement_type_id, amount_cents, reason.to_s.strip ].join("|")
      )
    end

    def cash_movement_presentation(type_name:, amount_cents:)
      PendingApprovalAction::Presentation.new(
        title: "Approval required",
        action_summary: "Cash movement: #{type_name}",
        boundary: "Your authority is insufficient for this cash movement.",
        material_values: "Amount #{money(amount_cents)}",
        effect: "The cash movement will post to the open session after approval."
      )
    end

    def unlinked_return_fingerprint(payload)
      Digest::SHA256.hexdigest(
        [
          "unlinked_return",
          payload["pos_transaction_id"],
          payload["product_variant_id"],
          payload["quantity"],
          payload["unit_price_cents"],
          payload["return_reason_id"],
          payload["return_disposition"],
          payload["return_source"]
        ].join("|")
      )
    end

    def unlinked_return_presentation(description:, quantity:, unit_price_cents:)
      PendingApprovalAction::Presentation.new(
        title: "Approval required",
        action_summary: "No-receipt return: #{description}",
        boundary: "Your authority is insufficient for this unlinked return.",
        material_values: "Qty #{quantity} · #{money(unit_price_cents)} each",
        effect: "The return line will be added after approval."
      )
    end

    def refund_exception_fingerprint(pos_transaction:, destination:, amount_cents:, original_tender_id:)
      Digest::SHA256.hexdigest(
        [ "refund_exception", pos_transaction.id, destination, amount_cents, original_tender_id ].join("|")
      )
    end

    def refund_exception_presentation(destination:, amount_cents:)
      PendingApprovalAction::Presentation.new(
        title: "Approval required",
        action_summary: "Refund destination exception",
        boundary: "This refund skips remaining original stored-value restoration.",
        material_values: "#{destination.to_s.humanize} · #{money(amount_cents)}",
        effect: "The refund tender will record after exception approval."
      )
    end

    def money(cents)
      format("$%.2f", cents.to_i / 100.0)
    end
  end
end
