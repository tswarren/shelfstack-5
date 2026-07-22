# frozen_string_literal: true

module Pos
  # Shared validation helpers for PrepareCardRefund and AddCardRefundTender.
  module CardRefundSupport
    Error = Class.new(StandardError)

    module_function

    def refund_due_cents(transaction, net_total_cents)
      already = transaction.pos_tenders.unresolved.where(direction: "refunded").sum(:amount_cents)
      [ -net_total_cents - already, 0 ].max
    end

    def assert_no_post_voided_linked_originals!(transaction)
      transaction.pos_line_items.pending.returns.find_each do |line|
        original = line.original_pos_line_item
        next if original.blank?
        raise Error, "cannot refund against a post-voided original sale" if original.post_voided?
      end
    end

    def validate_original!(transaction:, original_pos_tender:, amount_cents:, excluding_refund_tender: nil)
      return nil if original_pos_tender.blank?

      original_txn = PosTransaction.find(original_pos_tender.pos_transaction_id)
      raise Error, "original tender's transaction has been post-voided" if original_txn.post_voided?
      unless linked_original_transaction?(transaction, original_txn)
        raise Error, "original tender is not linked to this return transaction"
      end

      original = PosTender.find(original_pos_tender.id)
      raise Error, "original tender is not completed" unless original.completed?
      raise Error, "original tender is not a received tender" unless original.direction == "received"
      raise Error, "original tender has been post-voided" if original.post_voided?
      raise Error, "original tender store mismatch" unless original.store_id == transaction.store_id
      raise Error, "original tender must be card" unless original.tender_type.tender_category == "card"

      remaining = original.remaining_refundable_cents
      if excluding_refund_tender.present? &&
         excluding_refund_tender.original_pos_tender_id == original.id &&
         %w[pending authorized completed].include?(excluding_refund_tender.status)
        remaining += excluding_refund_tender.amount_cents
      end
      if amount_cents > remaining
        raise Error, "refund exceeds remaining refundable on original tender (#{remaining})"
      end

      original
    end

    def linked_original_transaction?(transaction, original_txn)
      transaction.pos_line_items.pending.returns.any? { |line|
        line.original_pos_line_item&.pos_transaction_id == original_txn.id
      }
    end
  end
end
