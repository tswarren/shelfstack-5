# frozen_string_literal: true

module Pos
  # Cash refund tender for transactions whose net total is negative (linked returns).
  class AddCashRefundTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      original_pos_tender: nil,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @original_pos_tender = original_pos_tender
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be cash" unless @tender_type.tender_category == "cash"
      raise Error, "refund amount must be positive" unless @amount_cents.positive?
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_refund_enabled!(@tender_type)

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        assert_no_post_voided_linked_originals!(transaction)

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        refund_due = [ -recalculation.net_total_cents - already_refunded_cents(transaction), 0 ].max
        raise Error, "no refund balance due" if refund_due.zero?
        raise Error, "refund exceeds balance due (#{refund_due})" if @amount_cents > refund_due

        original = lock_and_validate_original!(transaction)
        approval = RefundAllocationPolicy.call(
          pos_transaction: transaction,
          actor: @actor,
          destination: :cash,
          amount_cents: @amount_cents,
          original_pos_tender: original,
          exception_approver: @exception_approver,
          exception_approver_pin: @exception_approver_pin
        )

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "refunded", status: "pending", amount_cents: @amount_cents,
          original_pos_tender: original,
          created_by_user: @actor,
          pos_approval: approval
        )

        Result.new(pos_tender: tender, success?: true, error: nil, warnings: recalculation.warnings)
      end
    rescue Error, RefundAllocationPolicy::Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def lock_and_validate_original!(transaction)
      return nil if @original_pos_tender.blank?

      original_txn = PosTransaction.lock.find(@original_pos_tender.pos_transaction_id)
      raise Error, "original tender's transaction has been post-voided" if original_txn.post_voided?
      raise Error, "original tender is not linked to this return transaction" unless linked_original_transaction?(transaction, original_txn)

      original = PosTender.lock.find(@original_pos_tender.id)
      raise Error, "original tender is not completed" unless original.completed?
      raise Error, "original tender is not a received tender" unless original.direction == "received"
      raise Error, "original tender has been post-voided" if original.post_voided?
      raise Error, "original tender store mismatch" unless original.store_id == transaction.store_id
      raise Error, "original tender must be cash" unless original.tender_type.tender_category == "cash"

      remaining = original.remaining_refundable_cents
      raise Error, "refund exceeds remaining refundable on original tender (#{remaining})" if @amount_cents > remaining

      original
    end

    def linked_original_transaction?(transaction, original_txn)
      transaction.pos_line_items.pending.returns.any? { |line|
        line.original_pos_line_item&.pos_transaction_id == original_txn.id
      }
    end

    def assert_no_post_voided_linked_originals!(transaction)
      transaction.pos_line_items.pending.returns.find_each do |line|
        original = line.original_pos_line_item
        next if original.blank?
        raise Error, "cannot refund against a post-voided original sale" if original.post_voided?
      end
    end

    def already_refunded_cents(transaction)
      transaction.pos_tenders.unresolved.where(direction: "refunded").sum(:amount_cents)
    end
  end
end
