# frozen_string_literal: true

module Pos
  # Server-side preflight before the cashier processes a standalone card refund
  # on the external terminal. Locks the return transaction and every linked
  # original sale/tender so the plan cannot silently drift under concurrent
  # activity. Does not create a tender — AddCardRefundTender records the
  # external authorization afterward (always retaining a durable fact).
  class PrepareCardRefund < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:ready?, :refund_due_cents, :original_pos_tender, :error, :warnings)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      original_pos_tender: nil,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @original_pos_tender = original_pos_tender
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "refund amount must be positive" unless @amount_cents.positive?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_refund_enabled!(@tender_type)

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        RefundLockOrder.lock_linked_originals!(transaction)

        recalculation = RecalculateTransaction.call(pos_transaction: transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        refund_due = CardRefundSupport.refund_due_cents(transaction, recalculation.net_total_cents)
        raise Error, "no refund balance due" if refund_due.zero?
        raise Error, "refund exceeds balance due (#{refund_due})" if @amount_cents > refund_due

        original = CardRefundSupport.validate_original!(
          transaction: transaction,
          original_pos_tender: @original_pos_tender,
          amount_cents: @amount_cents
        )
        CardRefundSupport.assert_no_post_voided_linked_originals!(transaction)

        RefundAllocationPolicy.call(
          pos_transaction: transaction,
          actor: @actor,
          destination: :card,
          amount_cents: @amount_cents,
          original_pos_tender: original,
          exception_approver: @exception_approver,
          exception_approver_pin: @exception_approver_pin
        )

        Result.new(
          ready?: true,
          refund_due_cents: refund_due,
          original_pos_tender: original,
          error: nil,
          warnings: recalculation.warnings
        )
      end
    rescue Error, CardRefundSupport::Error, RefundAllocationPolicy::Error, TenderGuards::Error,
           ActiveRecord::RecordInvalid => e
      Result.new(
        ready?: false, refund_due_cents: nil, original_pos_tender: nil,
        error: e.message, warnings: []
      )
    end
  end
end
