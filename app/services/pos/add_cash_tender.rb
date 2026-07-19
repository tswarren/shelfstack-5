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

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        balance_due = [ recalculation.net_total_cents - already_tendered_cents(transaction), 0 ].max
        applied = [ @amount_tendered_cents, balance_due ].min
        change = @amount_tendered_cents - applied

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "received", status: "pending", amount_cents: applied,
          amount_tendered_cents: @amount_tendered_cents, change_due_cents: change,
          created_by_user: @actor
        )

        Result.new(pos_tender: tender, success?: true, error: nil,
                   warnings: recalculation.blockers + recalculation.warnings)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def already_tendered_cents(transaction)
      transaction.pos_tenders.unresolved.where(direction: "received").sum(:amount_cents)
    end
  end
end
