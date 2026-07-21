# frozen_string_literal: true

require "bigdecimal"

module Pos
  # Owns provisional recalculation: prices (already on lines) -> discounts (already
  # allocated) -> tax -> totals. Sale lines use Tax::CalculateTransaction. Linked
  # return lines reverse stored original tax components (ADR-0014) rather than
  # recalculating current rules.
  class RecalculateTransaction < ApplicationService
    Result = Data.define(:success?, :blockers, :warnings, :subtotal_cents, :discount_total_cents,
                          :tax_total_cents, :net_total_cents, :tax_exempt?)

    def initialize(pos_transaction:)
      @pos_transaction = pos_transaction
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        lines = transaction.pos_line_items.pending.order(:position).to_a
        sale_lines = lines.select { |line| line.direction == "sale" }
        return_lines = lines.select { |line| line.direction == "return" }
        merchandise_sale_lines = sale_lines.reject { |line| line.line_kind == "stored_value" }
        stored_value_sale_total = sale_lines.select { |line| line.line_kind == "stored_value" }
                                            .sum(&:extended_price_cents)

        sale_subtotal = merchandise_sale_lines.sum(&:extended_price_cents)
        return_subtotal = return_lines.sum(&:extended_price_cents)
        sale_discounts = discount_total_for(merchandise_sale_lines)
        return_discounts = discount_total_for(return_lines)
        provisional_net = (sale_subtotal - sale_discounts + stored_value_sale_total) -
                          (return_subtotal - return_discounts)

        if sale_discounts > sale_subtotal || return_discounts > return_subtotal
          return Result.new(success?: false,
                            blockers: [ "discount allocations exceed merchandise gross for one or more lines" ],
                            warnings: [],
                            subtotal_cents: sale_subtotal - return_subtotal,
                            discount_total_cents: sale_discounts - return_discounts,
                            tax_total_cents: pending_tax_total_cents(transaction),
                            net_total_cents: provisional_net,
                            tax_exempt?: false)
        end

        if transaction.tax_exempt?
          clear_pending_tax_rows!(transaction)
          return_tax_cents = persist_return_tax!(return_lines)
          # Whole-transaction exemption suppresses sale tax only. Linked returns
          # still reverse historically stored components so the customer is refunded.
          tax_total = -return_tax_cents
          net = provisional_net - return_tax_cents
          return Result.new(success?: true, blockers: [], warnings: [],
                            subtotal_cents: sale_subtotal - return_subtotal,
                            discount_total_cents: sale_discounts - return_discounts,
                            tax_total_cents: tax_total, net_total_cents: net, tax_exempt?: true)
        end

        sale_tax_result = calculate_sale_tax(transaction, merchandise_sale_lines, persist: false)
        if sale_tax_result[:blockers].any?
          # Do not wipe previously persisted provisional tax when calculation is blocked.
          existing_tax = pending_tax_total_cents(transaction)
          return Result.new(success?: false, blockers: sale_tax_result[:blockers],
                            warnings: sale_tax_result[:warnings],
                            subtotal_cents: sale_subtotal - return_subtotal,
                            discount_total_cents: sale_discounts - return_discounts,
                            tax_total_cents: existing_tax,
                            net_total_cents: provisional_net + existing_tax,
                            tax_exempt?: false)
        end

        clear_pending_tax_rows!(transaction)
        persist_tax_components(sale_tax_result[:line_results])
        return_tax_cents = persist_return_tax!(return_lines)
        sale_tax_cents = sale_tax_result[:tax_cents]
        tax_total = sale_tax_cents - return_tax_cents
        net = (sale_subtotal - sale_discounts + sale_tax_cents + stored_value_sale_total) -
              (return_subtotal - return_discounts + return_tax_cents)

        Result.new(success?: true, blockers: [], warnings: sale_tax_result[:warnings],
                   subtotal_cents: sale_subtotal - return_subtotal,
                   discount_total_cents: sale_discounts - return_discounts,
                   tax_total_cents: tax_total, net_total_cents: net, tax_exempt?: false)
      end
    end

    private

    def clear_pending_tax_rows!(transaction)
      PosLineItemTax.where(pos_line_item_id: transaction.pos_line_items.where.not(status: "completed").select(:id)).delete_all
    end

    def pending_tax_total_cents(transaction)
      PosLineItemTax.where(pos_line_item_id: transaction.pos_line_items.pending.select(:id)).sum(:amount_cents)
    end

    def discount_total_for(lines)
      return 0 if lines.empty?

      PosDiscountAllocation.joins(:pos_discount).where(pos_line_item_id: lines.map(&:id)).sum(:allocated_amount_cents)
    end

    def calculate_sale_tax(transaction, sale_lines, persist: true)
      return { tax_cents: 0, blockers: [], warnings: [], line_results: [] } if sale_lines.empty?

      tax_lines = sale_lines.map { |line| tax_input_line(line) }
      calculation = Tax::CalculateTransaction.call(store: transaction.store, lines: tax_lines)
      if calculation.blockers.any?
        return { tax_cents: 0, blockers: calculation.blockers, warnings: calculation.warnings, line_results: [] }
      end

      persist_tax_components(calculation.lines) if persist
      {
        tax_cents: calculation.total_tax_cents_by_direction.fetch("sale", 0),
        blockers: [],
        warnings: calculation.warnings,
        line_results: calculation.lines
      }
    end

    def persist_return_tax!(return_lines)
      total = 0
      return_lines.each do |line|
        original = line.original_pos_line_item
        next if original.blank?

        prior_qty = prior_return_quantity(original, excluding: line)
        originals = original.pos_line_item_taxes.order(:position).to_a
        originals.each do |tax|
          amount = cumulative_reversal_cents(tax.amount_cents, original.quantity, prior_qty, line.quantity)
          taxable = tax.taxable_amount_cents &&
            cumulative_reversal_cents(tax.taxable_amount_cents, original.quantity, prior_qty, line.quantity)
          line.pos_line_item_taxes.create!(
            store_tax_rule_id: tax.store_tax_rule_id,
            store_tax_rate_id: tax.store_tax_rate_id,
            tax_category_id: tax.tax_category_id,
            treatment_snapshot: tax.treatment_snapshot,
            receipt_code_snapshot: tax.receipt_code_snapshot,
            position: tax.position,
            taxable_amount_cents: taxable || 0,
            taxable_fraction_snapshot: tax.taxable_fraction_snapshot,
            rate: tax.rate,
            compounds_on_prior_tax_snapshot: tax.compounds_on_prior_tax_snapshot,
            amount_cents: amount
          )
          total += amount
        end
      end
      total
    end

    # Cumulative-target residual policy: each partial return receives
    # round(original × cumulative_qty / original_qty) − already_reversed, so the
    # final unit absorbs any leftover cent and the sum never exceeds the original.
    def cumulative_reversal_cents(original_amount, original_qty, prior_qty, this_qty)
      return 0 if original_amount.nil? || original_qty.to_i <= 0

      target_after = ((BigDecimal(original_amount) * (prior_qty + this_qty)) / original_qty)
                      .round(0, BigDecimal::ROUND_HALF_UP).to_i
      target_before = ((BigDecimal(original_amount) * prior_qty) / original_qty)
                       .round(0, BigDecimal::ROUND_HALF_UP).to_i
      target_after - target_before
    end

    # Completed prior returns plus earlier pending return lines in *this* transaction
    # only. Unrelated open/suspended pending returns may reserve quantity but must not
    # claim financial residual cents (cancelled pending txns would otherwise skew allocation).
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

    def proportional_cents(total, original_qty, return_qty)
      ((BigDecimal(total) * return_qty) / original_qty).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def tax_input_line(line)
      reducing_discount_cents = PosDiscountAllocation
        .joins(:pos_discount)
        .where(pos_line_item_id: line.id, pos_discounts: { tax_treatment: "reduces_taxable_base" })
        .sum(:allocated_amount_cents)

      taxable_cents = [ line.extended_price_cents - reducing_discount_cents, 0 ].max

      Tax::CalculateTransaction::Line.new(
        id: line.id,
        tax_category_id: line.tax_category_id,
        direction: "sale",
        taxable_merchandise_amount_cents: taxable_cents,
        position: line.position
      )
    end

    def persist_tax_components(line_results)
      now = Time.current

      line_results.each do |line_result|
        line_result.components.each do |component|
          PosLineItemTax.create!(
            pos_line_item_id: line_result.line_id,
            store_tax_rule_id: component.store_tax_rule_id,
            store_tax_rate_id: component.store_tax_rate_id,
            tax_category_id: component.tax_category_id,
            treatment_snapshot: component.treatment_snapshot,
            receipt_code_snapshot: component.receipt_code_snapshot,
            position: component.position,
            taxable_amount_cents: component.taxable_amount_cents,
            taxable_fraction_snapshot: component.taxable_fraction_snapshot,
            rate: component.rate,
            compounds_on_prior_tax_snapshot: component.compounds_on_prior_tax_snapshot,
            amount_cents: component.amount_cents,
            created_at: now
          )
        end

        line_result.exempt_components.each_with_index do |exempt, index|
          rule = StoreTaxRule.find(exempt.store_tax_rule_id)
          PosLineItemTax.create!(
            pos_line_item_id: line_result.line_id,
            store_tax_rule_id: exempt.store_tax_rule_id,
            store_tax_rate_id: rule.store_tax_rate_id,
            tax_category_id: exempt.tax_category_id,
            treatment_snapshot: exempt.treatment_snapshot,
            receipt_code_snapshot: rule.store_tax_rate&.receipt_code,
            position: line_result.components.size + index,
            taxable_amount_cents: 0,
            taxable_fraction_snapshot: rule.taxable_fraction,
            rate: rule.store_tax_rate&.rate,
            compounds_on_prior_tax_snapshot: rule.compounds_on_prior_tax,
            amount_cents: 0,
            created_at: now
          )
        end
      end
    end
  end
end
