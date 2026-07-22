# frozen_string_literal: true

require "bigdecimal"

module Pos
  # Under locks on related original sale lines, reassigns historical discount and
  # cost residuals onto pending return lines so concurrent return completions
  # cannot permanently drop cents. Tax is then recomputed by RecalculateTransaction.
  class ReassignReturnResiduals < ApplicationService
    def initialize(pos_transaction:, return_lines:)
      @pos_transaction = pos_transaction
      @return_lines = return_lines
    end

    def call
      ordered = @return_lines
        .select { |line| line.direction == "return" && line.original_pos_line_item_id.present? }
        .sort_by { |line| [ line.position, line.id ] }

      ordered.each do |return_line|
        original = return_line.original_pos_line_item
        next if original.blank?

        prior_qty = prior_return_quantity(original, excluding: return_line)
        reassign_cost!(return_line, original, prior_qty)
        reassign_discounts!(return_line, original, prior_qty)
      end
    end

    private

    def reassign_cost!(return_line, original, prior_qty)
      amount = cumulative_reversal_cents(
        original.cost_extended_cents, original.quantity, prior_qty, return_line.quantity
      )
      return if return_line.cost_extended_cents == amount

      return_line.update!(cost_extended_cents: amount)
    end

    def reassign_discounts!(return_line, original, prior_qty)
      return_line.pos_discount_allocations.includes(:pos_discount).find_each do |allocation|
        discount = allocation.pos_discount
        allocation.destroy!
        discount.destroy!
      end

      original.pos_discount_allocations.includes(:pos_discount).find_each do |allocation|
        amount = cumulative_reversal_cents(
          allocation.allocated_amount_cents, original.quantity, prior_qty, return_line.quantity
        )
        next if amount.nil? || amount.zero?

        source = allocation.pos_discount
        eligible = allocation.eligible_amount_cents &&
          cumulative_reversal_cents(
            allocation.eligible_amount_cents, original.quantity, prior_qty, return_line.quantity
          )

        discount = PosDiscount.create!(
          pos_transaction: @pos_transaction,
          target_pos_line_item: return_line,
          scope: "line",
          method: "fixed_amount",
          tax_treatment: source.tax_treatment,
          position: (@pos_transaction.pos_discounts.maximum(:position) || 0) + 1,
          base_amount_cents: return_line.extended_price_cents,
          requested_amount_cents: amount,
          applied_amount_cents: amount,
          discount_reason: source.discount_reason,
          created_by_user: return_line.created_by_user
        )
        PosDiscountAllocation.create!(
          pos_discount: discount,
          pos_line_item: return_line,
          allocated_amount_cents: amount,
          eligible_amount_cents: eligible
        )
      end
    end

    def cumulative_reversal_cents(original_amount, original_qty, prior_qty, this_qty)
      return 0 if original_amount.nil? || original_qty.to_i <= 0

      target_after = ((BigDecimal(original_amount) * (prior_qty + this_qty)) / original_qty)
                      .round(0, BigDecimal::ROUND_HALF_UP).to_i
      target_before = ((BigDecimal(original_amount) * prior_qty) / original_qty)
                       .round(0, BigDecimal::ROUND_HALF_UP).to_i
      target_after - target_before
    end

    def prior_return_quantity(original, excluding:)
      completed = PosLineItem
        .where(original_pos_line_item_id: original.id, status: "completed", direction: "return")
        .sum(:quantity)

      return completed unless excluding&.persisted? && excluding.pos_transaction_id.present?

      earlier_same_txn = PosLineItem
        .where(
          pos_transaction_id: excluding.pos_transaction_id,
          original_pos_line_item_id: original.id,
          status: "pending",
          direction: "return"
        )
        .where.not(id: excluding.id)
        .where(
          "(position < ?) OR (position = ? AND id < ?)",
          excluding.position, excluding.position, excluding.id
        )
        .sum(:quantity)

      completed + earlier_same_txn
    end
  end
end
