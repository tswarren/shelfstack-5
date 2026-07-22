# frozen_string_literal: true

module Pos
  # Records an operator-confirmed standalone-terminal card refund directly
  # (no preparation table). New tender references are recorded; original tender
  # refs are never copied. When amount becomes unattachable after refs are
  # entered, returns amount_mismatch? for mandatory record-and-void.
  class AddCardRefundTender < ApplicationService
    Error = Class.new(StandardError)
    AmountMismatch = Class.new(Error)
    Result = Data.define(:pos_tender, :success?, :error, :warnings, :amount_mismatch?)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      authorization_code: nil,
      terminal_reference: nil,
      reference_1: nil,
      reference_2: nil,
      original_pos_tender: nil,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @authorization_code = authorization_code
      @terminal_reference = terminal_reference
      @reference_1 = reference_1
      @reference_2 = reference_2
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

      refs = ValidateTenderReferences.call(
        tender_type: @tender_type,
        reference_1: @reference_1,
        reference_2: @reference_2,
        authorization_code: @authorization_code,
        terminal_reference: @terminal_reference
      )

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        CardRefundSupport.assert_no_post_voided_linked_originals!(transaction)

        recalculation = FinalizeReturnFinancials.call(pos_transaction: transaction).recalculation
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        refund_due = CardRefundSupport.refund_due_cents(transaction, recalculation.net_total_cents)
        if refund_due.zero? || @amount_cents > refund_due
          raise AmountMismatch,
                "refund amount is not attachable (remaining #{refund_due}); " \
                "confirm external void and record as voided"
        end

        begin
          original = CardRefundSupport.validate_original!(
            transaction: transaction,
            original_pos_tender: @original_pos_tender,
            amount_cents: @amount_cents
          )
        rescue CardRefundSupport::AmountMismatch => e
          raise AmountMismatch, e.message
        end

        approval = RefundAllocationPolicy.call(
          pos_transaction: transaction,
          actor: @actor,
          destination: :card,
          amount_cents: @amount_cents,
          original_pos_tender: original,
          exception_approver: @exception_approver,
          exception_approver_pin: @exception_approver_pin
        )

        tender = PosTender.create!(
          pos_transaction: transaction,
          store: transaction.store,
          tender_type: @tender_type,
          direction: "refunded",
          status: "authorized",
          amount_cents: @amount_cents,
          authorization_code: refs.authorization_code,
          terminal_reference: refs.terminal_reference,
          authorized_at: Time.current,
          original_pos_tender: original,
          created_by_user: @actor,
          pos_approval: approval
        )

        Result.new(
          pos_tender: tender, success?: true, error: nil,
          warnings: Array(recalculation.warnings), amount_mismatch?: false
        )
      end
    rescue AmountMismatch => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [], amount_mismatch?: true)
    rescue Error, CardRefundSupport::Error, RefundAllocationPolicy::Error,
           ValidateTenderReferences::Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [], amount_mismatch?: false)
    end
  end
end
