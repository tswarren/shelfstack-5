# frozen_string_literal: true

module Pos
  # Read-model SV-first refund proposal for Phase 11.2F. Does not mutate tenders;
  # recording still goes through Add*RefundTender + RefundAllocationPolicy.
  class ProposeRefundPlan < ApplicationService
    PlanRow = Data.define(:destination, :label, :amount_cents, :original_pos_tender, :recommended?)
    Result = Data.define(:refund_due_cents, :rows)

    def initialize(pos_transaction:, refund_due_cents: nil)
      @pos_transaction = pos_transaction
      @refund_due_cents = refund_due_cents
    end

    def call
      due = @refund_due_cents
      if due.nil?
        recalc = RecalculateTransaction.call(pos_transaction: @pos_transaction)
        received = @pos_transaction.pos_tenders.unresolved.where(direction: "received").sum(:amount_cents)
        refunded = @pos_transaction.pos_tenders.unresolved.where(direction: "refunded").sum(:amount_cents)
        balance = recalc.net_total_cents - (received - refunded)
        due = [ -balance, 0 ].max
      end
      due = due.to_i
      return Result.new(refund_due_cents: due, rows: []) if due <= 0

      remaining = due
      rows = []

      RefundAllocationPolicy.remaining_original_sv_tenders(@pos_transaction).each do |tender|
        break if remaining <= 0

        capacity = allocatable_capacity(tender)
        next if capacity <= 0

        amount = [ capacity, remaining ].min
        rows << PlanRow.new(
          destination: :original_stored_value,
          label: "Stored value (original)",
          amount_cents: amount,
          original_pos_tender: tender,
          recommended?: true
        )
        remaining -= amount
      end

      if remaining.positive?
        cash_original = RefundAllocationPolicy.remaining_original_tenders(@pos_transaction).find { |t|
          t.tender_type.tender_category == "cash"
        }
        rows << PlanRow.new(
          destination: :cash,
          label: cash_original ? "Cash (original)" : "Cash",
          amount_cents: remaining,
          original_pos_tender: cash_original,
          recommended?: true
        )
      end

      Result.new(refund_due_cents: due, rows: rows)
    end

    private

    def allocatable_capacity(original_tender)
      completed = original_tender.refund_tenders.where(status: "completed").sum(:amount_cents)
      other_inflight = original_tender.refund_tenders
        .where(status: %w[pending authorized])
        .where.not(pos_transaction_id: @pos_transaction.id)
        .sum(:amount_cents)
      plan_toward = @pos_transaction.pos_tenders.unresolved
        .where(direction: "refunded", original_pos_tender_id: original_tender.id)
        .sum(:amount_cents)
      original_tender.amount_cents - completed - other_inflight - plan_toward
    end
  end
end
