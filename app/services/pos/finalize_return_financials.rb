# frozen_string_literal: true

module Pos
  # Finalizes historical return residuals under original-line locks, then
  # recalculates tax/totals. Call from refund prepare/add paths (and return
  # transaction show) before computing refund-due amounts.
  #
  # Caller must hold a row lock on the return transaction.
  class FinalizeReturnFinancials < ApplicationService
    Result = Data.define(:recalculation)

    def initialize(pos_transaction:)
      @pos_transaction = pos_transaction
    end

    def call
      return_lines = @pos_transaction.pos_line_items.lock.pending.returns
        .order(:position, :id)
        .to_a

      if return_lines.any? { |line| line.original_pos_line_item_id.present? }
        RefundLockOrder.lock_linked_originals!(@pos_transaction)
        ReassignReturnResiduals.call(pos_transaction: @pos_transaction, return_lines: return_lines)
        return_lines.each(&:reload)
      end

      Result.new(recalculation: RecalculateTransaction.call(pos_transaction: @pos_transaction))
    end
  end
end
