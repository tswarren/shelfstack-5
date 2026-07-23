# frozen_string_literal: true

module PosHelper
  def pos_money(cents)
    format_money(cents)
  end

  def pos_discount_summary(discount)
    method_text = case discount.method
    when "percentage"
      rate = discount.rate_bps.to_i / 100.0
      "#{format("%g", rate)}%"
    when "fixed_amount"
      "Fixed amount"
    when "fixed_price"
      "to #{pos_money(discount.requested_amount_cents)}"
    else
      discount.method.to_s.humanize
    end

    parts = [ method_text, pos_money(discount.applied_amount_cents) ]
    parts << discount.discount_reason.name if discount.discount_reason.present?
    parts.join(" · ")
  end

  # Option label for selecting an original card tender when recording a refund.
  def pos_original_card_tender_option_label(tender)
    txn = tender.pos_transaction
    type = tender.tender_type
    ref1_label = type.reference_1_label.presence || "Ref 1"
    ref2_label = type.reference_2_label.presence || "Ref 2"
    parts = [
      "Receipt #{txn.receipt_number}",
      (formatted_datetime(txn.completed_at, format: :short) if txn.completed_at),
      pos_money(tender.amount_cents),
      "#{pos_money(tender.remaining_refundable_cents)} remaining"
    ]
    parts << "#{ref1_label}: #{tender.authorization_code}" if tender.authorization_code.present?
    parts << "#{ref2_label}: #{tender.terminal_reference}" if tender.terminal_reference.present?
    parts.compact.join(" · ")
  end
end
