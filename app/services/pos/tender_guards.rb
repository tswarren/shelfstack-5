# frozen_string_literal: true

module Pos
  # Shared Tender Type capability and commercial-blocker guards used by Add*Tender
  # services so controller dispatch cannot bypass inactive/disabled types.
  module TenderGuards
    Error = Class.new(StandardError)

    module_function

    def assert_active!(tender_type)
      raise Error, "tender type is inactive" unless tender_type.active?
    end

    def assert_payment_enabled!(tender_type)
      raise Error, "tender type is not payment-enabled" unless tender_type.payment_enabled?
    end

    def assert_refund_enabled!(tender_type)
      raise Error, "tender type is not refund-enabled" unless tender_type.refund_enabled?
    end

    def assert_no_calculation_blockers!(recalculation)
      return if recalculation.blockers.empty?

      raise Error, "cannot tender while calculation has blockers: #{recalculation.blockers.join(', ')}"
    end

    def remaining_received_balance_cents(transaction, net_total_cents)
      [ net_total_cents - transaction.pos_tenders.unresolved.where(direction: "received").sum(:amount_cents), 0 ].max
    end
  end
end
