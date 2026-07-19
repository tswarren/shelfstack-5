# frozen_string_literal: true

module Pos
  # Creates a linked return line that copies original completed commercial values
  # and reverses stored tax components exactly (proportional when returning a
  # partial remaining quantity). Never mutates the original sale line.
  class AddLinkedReturnLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_transaction:, original_pos_line_item:, quantity:, return_reason:,
                   return_disposition:, actor:)
      @pos_transaction = pos_transaction
      @original = original_pos_line_item
      @quantity = quantity.to_i
      @return_reason = return_reason
      @return_disposition = return_disposition.to_s
      @actor = actor
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "return disposition is invalid" unless PosLineItem::RETURN_DISPOSITIONS.include?(@return_disposition)
      raise Error, "original line must be a completed sale" unless @original.completed?
      raise Error, "original line must be a sale line" unless @original.direction == "sale"
      raise Error, "stores must match" unless @original.pos_transaction.store_id == @pos_transaction.store_id

      unless Authorization::EvaluatePermission.call(
        user: @actor, store: @pos_transaction.store, permission_key: "pos.return.create"
      ) == :allow
        raise Error, "missing permission pos.return.create"
      end

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        raise Error, "commercial fields are locked by unresolved tenders" unless transaction.editable?

        # Lock the original (already-completed) line so two concurrent linked
        # returns against it serialize their remaining-quantity check instead of
        # both reading a stale "remaining" value (domain invariant "Linked
        # Returns do not exceed remaining quantity").
        original = PosLineItem.lock.find(@original.id)
        remaining = original.remaining_returnable_quantity
        raise Error, "return quantity exceeds remaining returnable quantity (#{remaining})" if @quantity > remaining

        position = (transaction.pos_line_items.maximum(:position) || 0) + 1
        line = transaction.pos_line_items.create!(
          status: "pending",
          direction: "return",
          line_kind: original.line_kind,
          position: position,
          product_variant: original.product_variant,
          inventory_unit: (original.inventory_unit_id.present? && @quantity == 1 ? original.inventory_unit : nil),
          department: original.department,
          tax_category: original.tax_category,
          description_snapshot: original.description_snapshot,
          quantity: @quantity,
          unit_price_cents: original.unit_price_cents,
          original_pos_line_item: original,
          return_reason: @return_reason,
          return_disposition: @return_disposition,
          return_source: "linked_sale",
          created_by_user: @actor,
          cost_unit_cost_cents: original.cost_unit_cost_cents,
          cost_extended_cents: proportional_cents(original.cost_extended_cents, original.quantity, @quantity),
          cost_method_snapshot: original.cost_method_snapshot,
          cost_quality_snapshot: original.cost_quality_snapshot
        )

        # INV-RET-004: reverse historical Discount allocations proportionally onto
        # the return line (fixed-amount mirrors of the original share). Tax still
        # comes from stored original components in RecalculateTransaction — do not
        # re-run current discount/tax rules against the return.
        reverse_historical_discounts!(transaction, original, line)

        recalc = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        Result.new(pos_line_item: line, success?: true, error: nil,
                   warnings: recalc.blockers + recalc.warnings)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def reverse_historical_discounts!(transaction, original, return_line)
      original.pos_discount_allocations.includes(:pos_discount).find_each do |allocation|
        amount = proportional_cents(allocation.allocated_amount_cents, original.quantity, @quantity)
        next if amount.nil? || amount.zero?

        source = allocation.pos_discount
        eligible = allocation.eligible_amount_cents &&
          proportional_cents(allocation.eligible_amount_cents, original.quantity, @quantity)

        discount = PosDiscount.create!(
          pos_transaction: transaction,
          target_pos_line_item: return_line,
          scope: "line",
          method: "fixed_amount",
          tax_treatment: source.tax_treatment,
          position: (transaction.pos_discounts.maximum(:position) || 0) + 1,
          base_amount_cents: return_line.extended_price_cents,
          requested_amount_cents: amount,
          applied_amount_cents: amount,
          discount_reason: source.discount_reason,
          created_by_user: @actor
        )
        PosDiscountAllocation.create!(
          pos_discount: discount,
          pos_line_item: return_line,
          allocated_amount_cents: amount,
          eligible_amount_cents: eligible
        )
      end
    end

    def proportional_cents(total, original_qty, return_qty)
      return nil if total.nil?

      ((BigDecimal(total) * return_qty) / original_qty).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end
  end
end
