# frozen_string_literal: true

module Pos
  # INV-CASH-001 expected drawer cash for a cash-enabled Session.
  #
  # Cash received is physical cash taken (amount tendered). Change given and
  # cash refunded leave the drawer. Applied tender amount alone already nets
  # change, so it must not be combined with a separate change subtraction.
  class CalculateExpectedCash < ApplicationService
    Result = Data.define(
      :expected_cash_cents,
      :opening_cash_cents,
      :cash_received_cents,
      :change_given_cents,
      :cash_refunded_cents,
      :cash_movement_in_cents,
      :cash_movement_out_cents
    )

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
      # Prefer amount tendered (cash put in the drawer). Fall back to applied
      # amount when tendered was never recorded (should not happen for cash).
      cash_received = received.sum(Arel.sql("COALESCE(amount_tendered_cents, amount_cents)"))
      change_given = received.sum(Arel.sql("COALESCE(change_due_cents, 0)"))
      cash_refunded = tenders.where(direction: "refunded").sum(:amount_cents)

      movements = @pos_session.pos_cash_movements.joins(:cash_movement_type)
      movement_in = movements.where(cash_movement_types: { direction: "cash_in" }).sum(:amount_cents)
      movement_out = movements.where(cash_movement_types: { direction: "cash_out" }).sum(:amount_cents)

      expected = opening + cash_received - change_given - cash_refunded + movement_in - movement_out
      Result.new(
        expected_cash_cents: expected,
        opening_cash_cents: opening,
        cash_received_cents: cash_received,
        change_given_cents: change_given,
        cash_refunded_cents: cash_refunded,
        cash_movement_in_cents: movement_in,
        cash_movement_out_cents: movement_out
      )
    end
  end
end
