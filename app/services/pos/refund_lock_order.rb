# frozen_string_literal: true

module Pos
  # Lock order for refund plan reservation / card-refund recording:
  # current transaction (caller) → linked original transactions →
  # original lines → original received tenders (sorted IDs).
  module RefundLockOrder
    module_function

    def lock_linked_originals!(transaction)
      return_lines = transaction.pos_line_items.pending.returns
        .where.not(original_pos_line_item_id: nil)
        .to_a

      original_line_ids = return_lines.map(&:original_pos_line_item_id).uniq.sort
      return { lines: {}, tenders: {} } if original_line_ids.empty?

      sale_txn_ids = PosLineItem.where(id: original_line_ids).distinct.pluck(:pos_transaction_id).sort
      sale_txn_ids.each { |id| PosTransaction.lock.find(id) }

      locked_lines = original_line_ids.index_with { |id| PosLineItem.lock.find(id) }

      tender_ids = PosTender
        .where(pos_transaction_id: sale_txn_ids, direction: "received", status: "completed")
        .order(:id)
        .pluck(:id)
      locked_tenders = tender_ids.index_with { |id| PosTender.lock.find(id) }

      { lines: locked_lines, tenders: locked_tenders }
    end
  end
end
