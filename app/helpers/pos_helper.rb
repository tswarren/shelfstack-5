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

  # Masked reference for Recovery affected-activity and void-required rows.
  def pos_masked_tender_reference(tender)
    parts = []
    if tender.authorization_code.present?
      parts << "Auth #{pos_mask_token(tender.authorization_code)}"
    end
    if tender.terminal_reference.present?
      parts << "Term #{pos_mask_token(tender.terminal_reference)}"
    end
    parts.presence&.join(" · ") || "No external reference recorded"
  end

  def pos_mask_token(value)
    text = value.to_s
    return text if text.length <= 4

    "#{'•' * [ text.length - 4, 4 ].min}#{text[-4, 4]}"
  end

  def pos_receipt_line_identifier(line)
    if line.line_kind == "open_ring"
      dept = line.department
      return "Dept #{dept.department_number}" if dept&.department_number.present?
      return "Dept #{dept.code}" if dept&.code.present?
    end

    return line.identifier_snapshot if line.identifier_snapshot.present?
    return unless line.line_kind == "product" && !line.completed?

    # Open lines may still resolve live catalog; completed receipts use snapshots only.
    product = line.product_variant&.product
    product&.identifier.presence || line.product_variant&.sku
  end

  # Customer-facing line title. Stored-value descriptions never include the full account number.
  def pos_receipt_line_description(line)
    if line.line_kind == "stored_value"
      return "Gift Card Reload" if line.stored_value_operation == "reload"

      return "Gift Card Sale"
    end

    line.effective_description.presence || line.description_snapshot.presence || "Line"
  end

  def pos_receipt_document_banner(pos_transaction)
    return "POST-VOID" if pos_transaction.reverses_pos_transaction_id.present?

    lines = pos_transaction.pos_line_items.select { |line| line.status == "completed" }
    has_sale = lines.any? { |line| line.sale? && line.line_kind != "stored_value" }
    has_return = lines.any?(&:return?)
    return "MIXED SALE / RETURN" if has_sale && has_return
    return "RETURN" if has_return && !has_sale

    "RECEIPT"
  end

  def pos_store_address_lines(store = Current.store)
    return [] if store.blank?

    [
      store.address_line_1,
      store.address_line_2,
      [ store.city, store.region, store.postal_code ].compact_blank.join(", ").presence,
      store.phone.presence
    ].compact_blank
  end

  def pos_receipt_discount_label(discount)
    return "Discount" if discount.blank?

    reason = discount.discount_reason&.name
    return reason if reason.present?

    case discount.method
    when "percentage"
      rate = discount.rate_bps.to_i / 100.0
      "Discount #{format("%g", rate)}%"
    else
      "Discount"
    end
  end

  # Customer/Post-Void receipt totals tax row: "Tax T ($83.05 @ 6.000%)"
  def pos_receipt_tax_component_label(component)
    code = component[:code].presence || "Tax"
    rate = component[:rate]
    taxable = component[:taxable_amount_cents].to_i
    return "Tax #{code}" if rate.blank? && taxable.zero?

    rate_pct = rate.present? ? format("%.3f", rate.to_f * 100) : nil
    detail =
      if rate_pct.present?
        "#{pos_money(taxable)} @ #{rate_pct}%"
      else
        pos_money(taxable)
      end
    "Tax #{code} (#{detail})"
  end

  def pos_receipt_mask_account(number)
    text = number.to_s
    return nil if text.blank?
    return "****" if text.length < 4

    "****#{text[-4, 4]}"
  end

  def pos_receipt_tender_label(tender)
    name = tender.tender_type.name
    account = tender.stored_value_account
    return name if account.blank?

    masked = pos_receipt_mask_account(account.account_number)
    masked.present? ? "#{name} #{masked}" : name
  end

  def pos_receipt_tender_amount_cents(tender)
    amount = tender.amount_cents.to_i
    tender.direction == "refunded" ? -amount : amount
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
