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
      # Phase 7: also the shared threshold for accepting cash and card reconciliation differences.
      cash_variance_review_threshold_cents: { column: :cash_variance_review_threshold_cents, type: :money }
    }.freeze

    # OD-013 interim: null membership overrides deny as unconfigured. Bootstrap /
    # sync fills only *missing* administrator membership limits so the admin
    # user can operate POS without a second approver. Never overwrites a
    # deliberately configured value.
    ADMINISTRATOR_UNCONFIGURED_DEFAULTS = {
      maximum_discount_rate: BigDecimal("1"),
      maximum_discount_amount_cents: 2_147_483_647,
      maximum_price_override_rate: BigDecimal("1"),
      maximum_cash_refund_cents: 2_147_483_647,
      maximum_no_receipt_return_cents: 2_147_483_647,
      maximum_paid_out_cents: 2_147_483_647
    }.freeze

    module_function

    def definition_for(limit_key)
      DEFINITIONS[limit_key.to_sym]
    end

    def known?(limit_key)
      DEFINITIONS.key?(limit_key.to_sym)
    end

    def apply_administrator_defaults!(membership)
      attrs = {}
      ADMINISTRATOR_UNCONFIGURED_DEFAULTS.each do |attribute, value|
        attrs[attribute] = value if membership.public_send(attribute).nil?
      end
      membership.update!(attrs) if attrs.any?
      attrs.keys
    end
  end
end
