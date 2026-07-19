# frozen_string_literal: true

module Pos
  # Owns provisional recalculation order for an editable Transaction (domain
  # "Recalculation ownership"): resolve prices -> allocate discounts -> calculate tax
  # -> calculate transaction totals. Persists pending `pos_line_item_taxes` for pending
  # lines and returns totals for display; does not mutate cached totals on
  # `pos_transactions` (Phase 4b introduces no such columns — see
  # docs/implementation/phase-04-tax-schema.md).
  #
  # Line prices are already resolved on `pos_line_items.unit_price_cents` by the
  # mutating service that triggered recalculation (AddLine, OverridePrice, ...); this
  # service does not re-fetch catalog prices. Discount allocations are likewise read
  # as already persisted by Pos::ApplyDiscount; this service does not re-run
  # allocation, only tax against the currently allocated taxable base. Every pending
  # line is treated as direction "sale" — linked returns are Phase 4e.
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

        # Clear tax rows for every non-completed line (including just-removed lines),
        # not only currently pending ones, so a removal leaves no stale tax snapshot.
        PosLineItemTax.where(pos_line_item_id: transaction.pos_line_items.where.not(status: "completed").select(:id)).delete_all

        subtotal_cents = lines.sum(&:extended_price_cents)
        discount_total_cents = PosDiscountAllocation
          .joins(:pos_discount)
          .where(pos_line_item_id: lines.map(&:id))
          .sum(:allocated_amount_cents)

        if transaction.tax_exempt?
          Result.new(success?: true, blockers: [], warnings: [], subtotal_cents: subtotal_cents,
                     discount_total_cents: discount_total_cents, tax_total_cents: 0,
                     net_total_cents: subtotal_cents - discount_total_cents, tax_exempt?: true)
        else
          calculate_and_persist_tax(transaction, lines, subtotal_cents, discount_total_cents)
        end
      end
    end

    private

    def calculate_and_persist_tax(transaction, lines, subtotal_cents, discount_total_cents)
      tax_lines = lines.map { |line| tax_input_line(line) }
      calculation = Tax::CalculateTransaction.call(store: transaction.store, lines: tax_lines)

      if calculation.blockers.any?
        return Result.new(success?: false, blockers: calculation.blockers, warnings: calculation.warnings,
                           subtotal_cents: subtotal_cents, discount_total_cents: discount_total_cents,
                           tax_total_cents: 0, net_total_cents: subtotal_cents - discount_total_cents,
                           tax_exempt?: false)
      end

      persist_tax_components(calculation.lines)
      tax_total_cents = calculation.total_tax_cents_by_direction.fetch("sale", 0)

      Result.new(success?: true, blockers: [], warnings: calculation.warnings, subtotal_cents: subtotal_cents,
                 discount_total_cents: discount_total_cents, tax_total_cents: tax_total_cents,
                 net_total_cents: subtotal_cents - discount_total_cents + tax_total_cents, tax_exempt?: false)
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

        # Exempt rules collect no tax and form no calculation component, but the
        # snapshot is still persisted so receipts/audits can show which rule exempted
        # the line rather than silently omitting the category (ADR-0014).
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
