# frozen_string_literal: true

module Pos
  # INV-CASH-001 expected drawer cash for a cash-enabled Session.
  class CalculateExpectedCash < ApplicationService
    Result = Data.define(:expected_cash_cents)

    def initialize(pos_session:)
      @pos_session = pos_session
    end

    def call
      opening = @pos_session.opening_cash_cents.to_i

      tenders = PosTender
        .joins(:pos_transaction)
        .joins(:tender_type)
        .where(pos_transactions: { completed_pos_session_id: @pos_session.id, status: "completed" })
        .where(status: "completed")
        .where(tender_types: { tender_category: "cash" })

      received = tenders.where(direction: "received")
      cash_in = received.sum(:amount_cents)
      change_out = received.sum("COALESCE(change_due_cents, 0)")
      cash_refunded = tenders.where(direction: "refunded").sum(:amount_cents)

      movements = @pos_session.pos_cash_movements.joins(:cash_movement_type)
      movement_in = movements.where(cash_movement_types: { direction: "cash_in" }).sum(:amount_cents)
      movement_out = movements.where(cash_movement_types: { direction: "cash_out" }).sum(:amount_cents)

      expected = opening + cash_in - change_out - cash_refunded + movement_in - movement_out
      Result.new(expected_cash_cents: expected)
    end
  end
end
