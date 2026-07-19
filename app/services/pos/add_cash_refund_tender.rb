# frozen_string_literal: true

module Pos
  # Cash refund tender for transactions whose net total is negative (linked returns).
  class AddCashRefundTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings)

    def initialize(pos_transaction:, tender_type:, amount_cents:, actor:)
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be cash" unless @tender_type.tender_category == "cash"
      raise Error, "refund amount must be positive" unless @amount_cents.positive?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        refund_due = [ -recalculation.net_total_cents - already_refunded_cents(transaction), 0 ].max
        raise Error, "no refund balance due" if refund_due.zero?
        raise Error, "refund exceeds balance due (#{refund_due})" if @amount_cents > refund_due

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "refunded", status: "pending", amount_cents: @amount_cents,
          created_by_user: @actor
        )

        Result.new(pos_tender: tender, success?: true, error: nil,
                   warnings: recalculation.blockers + recalculation.warnings)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def already_refunded_cents(transaction)
      transaction.pos_tenders.unresolved.where(direction: "refunded").sum(:amount_cents)
    end
  end
end
