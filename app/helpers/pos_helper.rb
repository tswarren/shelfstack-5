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
end
