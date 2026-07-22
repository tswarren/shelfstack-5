# frozen_string_literal: true

module Pos
  # Standalone-card refund tender for linked returns (external auth confirmed first).
  class AddCardRefundTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      authorization_code:,
      actor:,
      terminal_reference: nil,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @authorization_code = authorization_code
      @terminal_reference = terminal_reference
      @actor = actor
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "refund amount must be positive" unless @amount_cents.positive?
      raise Error, "authorization code is required" if @authorization_code.blank?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_refund_enabled!(@tender_type)

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        refund_due = [ -recalculation.net_total_cents - already_refunded_cents(transaction), 0 ].max
        raise Error, "no refund balance due" if refund_due.zero?
        raise Error, "refund exceeds balance due (#{refund_due})" if @amount_cents > refund_due

        approval = RefundAllocationPolicy.call(
          pos_transaction: transaction,
          actor: @actor,
          destination: :card,
          amount_cents: @amount_cents,
          exception_approver: @exception_approver,
          exception_approver_pin: @exception_approver_pin
        )

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "refunded", status: "authorized", amount_cents: @amount_cents,
          authorization_code: @authorization_code, terminal_reference: @terminal_reference,
          authorized_at: Time.current, created_by_user: @actor,
          pos_approval: approval
        )

        Result.new(pos_tender: tender, success?: true, error: nil, warnings: recalculation.warnings)
      end
    rescue Error, RefundAllocationPolicy::Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def already_refunded_cents(transaction)
      transaction.pos_tenders.unresolved.where(direction: "refunded").sum(:amount_cents)
    end
  end
end
