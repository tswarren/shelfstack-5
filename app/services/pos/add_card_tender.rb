# frozen_string_literal: true

module Pos
  # Records an operator-confirmed standalone-terminal card payment.
  # ShelfStack does not drive the terminal; ADR-0009 confirm-before-complete.
  #
  # Amount must satisfy 0 < amount <= remaining received balance (unless the
  # tender type allows over-tender). When refs are valid but the amount is no
  # longer attachable, returns amount_mismatch? so the UI can require
  # record-and-void via RecordVoidedCardTender.
  class AddCardTender < ApplicationService
    Error = Class.new(StandardError)
    AmountMismatch = Class.new(Error)
    Result = Data.define(:pos_tender, :success?, :error, :warnings, :amount_mismatch?)

    def initialize(pos_transaction:, tender_type:, amount_cents:, actor:,
                   authorization_code: nil, terminal_reference: nil,
                   reference_1: nil, reference_2: nil)
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @authorization_code = authorization_code
      @terminal_reference = terminal_reference
      @reference_1 = reference_1
      @reference_2 = reference_2
      @actor = actor
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "amount must be positive" unless @amount_cents.positive?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_payment_enabled!(@tender_type)

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

        recalculation = recalculate_for_tender!(transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        balance_due = TenderGuards.remaining_received_balance_cents(transaction, recalculation.net_total_cents)
        raise Error, "no balance due" if balance_due.zero?

        if !@tender_type.allows_over_tender? && @amount_cents > balance_due
          raise AmountMismatch,
                "amount exceeds remaining balance (#{balance_due}); confirm external void and record as voided"
        end

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "received", status: "authorized", amount_cents: @amount_cents,
          authorization_code: refs.authorization_code, terminal_reference: refs.terminal_reference,
          authorized_at: Time.current, created_by_user: @actor
        )

        Result.new(pos_tender: tender, success?: true, error: nil, warnings: recalculation.warnings,
                   amount_mismatch?: false)
      end
    rescue AmountMismatch => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [], amount_mismatch?: true)
    rescue Error, ValidateTenderReferences::Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [], amount_mismatch?: false)
    end

    private

    def recalculate_for_tender!(transaction)
      if transaction.pos_line_items.pending.returns.where.not(original_pos_line_item_id: nil).exists?
        FinalizeReturnFinancials.call(pos_transaction: transaction).recalculation
      else
        RecalculateTransaction.call(pos_transaction: transaction)
      end
    end
  end
end
