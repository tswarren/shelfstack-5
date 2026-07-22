# frozen_string_literal: true

module Pos
  # Cash Tender (domain "Cash"): records amount presented and amount applied,
  # capping applied amount at the current balance due and returning any excess as
  # change. Created `pending` — `Pos::CompleteTransaction` finalizes it to
  # `completed` (domain "Recalculation ownership" / atomic-completion workflow).
  # Adding a Tender does not itself require the transaction to be otherwise
  # editable (it is how a split/second Tender is added), only that it is `open`.
  class AddCashTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings)

    def initialize(pos_transaction:, tender_type:, amount_tendered_cents:, actor:)
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_tendered_cents = amount_tendered_cents.to_i
      @actor = actor
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be cash" unless @tender_type.tender_category == "cash"
      raise Error, "amount tendered must be positive" unless @amount_tendered_cents.positive?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_payment_enabled!(@tender_type)

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        TenderGuards.assert_no_outstanding_card_refund_preparation!(transaction)

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        balance_due = TenderGuards.remaining_received_balance_cents(transaction, recalculation.net_total_cents)
        raise Error, "no balance due" if balance_due.zero?

        if !@tender_type.allows_over_tender? && @amount_tendered_cents > balance_due
          raise Error, "amount exceeds remaining balance (#{balance_due})"
        end

        applied = [ @amount_tendered_cents, balance_due ].min
        change = @amount_tendered_cents - applied
        if change.positive? && !@tender_type.provides_change?
          raise Error, "tender type does not provide change"
        end

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "received", status: "pending", amount_cents: applied,
          amount_tendered_cents: @amount_tendered_cents, change_due_cents: change,
          created_by_user: @actor
        )

        Result.new(pos_tender: tender, success?: true, error: nil, warnings: recalculation.warnings)
      end
    rescue Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [])
    end
  end
end
