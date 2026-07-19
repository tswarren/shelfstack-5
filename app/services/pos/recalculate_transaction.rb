# frozen_string_literal: true

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

        sale_subtotal = sale_lines.sum(&:extended_price_cents)
        return_subtotal = return_lines.sum(&:extended_price_cents)
        sale_discounts = discount_total_for(sale_lines)
        return_discounts = discount_total_for(return_lines)
        provisional_net = (sale_subtotal - sale_discounts) - (return_subtotal - return_discounts)

        if transaction.tax_exempt?
          clear_pending_tax_rows!(transaction)
          return Result.new(success?: true, blockers: [], warnings: [],
                            subtotal_cents: sale_subtotal - return_subtotal,
                            discount_total_cents: sale_discounts - return_discounts,
                            tax_total_cents: 0, net_total_cents: provisional_net, tax_exempt?: true)
        end

        sale_tax_result = calculate_sale_tax(transaction, sale_lines, persist: false)
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
        net = (sale_subtotal - sale_discounts + sale_tax_cents) - (return_subtotal - return_discounts + return_tax_cents)

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

        originals = original.pos_line_item_taxes.order(:position).to_a
        originals.each do |tax|
          amount = proportional_cents(tax.amount_cents, original.quantity, line.quantity)
          taxable = tax.taxable_amount_cents && proportional_cents(tax.taxable_amount_cents, original.quantity, line.quantity)
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
