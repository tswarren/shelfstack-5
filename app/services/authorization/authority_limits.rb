# frozen_string_literal: true

module Authorization
  module AuthorityLimits
    DEFINITIONS = {
      maximum_discount_rate: { column: :maximum_discount_rate, type: :rate },
      maximum_discount_amount_cents: { column: :maximum_discount_amount_cents, type: :money },
      maximum_price_override_rate: { column: :maximum_price_override_rate, type: :rate },
      maximum_cash_refund_cents: { column: :maximum_cash_refund_cents, type: :money },
      maximum_no_receipt_return_cents: { column: :maximum_no_receipt_return_cents, type: :money },
      maximum_paid_out_cents: { column: :maximum_paid_out_cents, type: :money },
      cash_variance_review_threshold_cents: { column: :cash_variance_review_threshold_cents, type: :money }
    }.freeze

    module_function

    def definition_for(limit_key)
      DEFINITIONS[limit_key.to_sym]
    end

    def known?(limit_key)
      DEFINITIONS.key?(limit_key.to_sym)
    end
  end
end
