# frozen_string_literal: true

require "bigdecimal"

module Tax
  # Pure calculation service implementing the ADR-0014 hybrid transaction-component tax
  # algorithm. Does not persist anything; Pos::RecalculateTransaction (Phase 4b) is the
  # service that stores pending discounts/tax/totals, and Pos::CompleteTransaction owns
  # finalizing `pos_line_item_taxes` rows.
  #
  # Input lines are duck-typed (see Line) rather than tied to PosLineItem, since Phase 4a
  # does not yet carry tax direction / taxable-merchandise-amount fields on that model.
  #
  # Missing an effective Store Tax Rule for a line's Tax Category is a blocker, never an
  # implicit exemption (ADR-0014).
  class CalculateTransaction < ApplicationService
    DIRECTIONS = %w[sale return].freeze
    COMPONENT_TREATMENTS = %w[taxable zero_rated].freeze

    # id:                                  caller-supplied identifier (used for tie-breaks; must be comparable)
    # tax_category_id:                     resolved Tax Category for the line
    # direction:                           "sale" or "return" — separate rounding pools
    # taxable_merchandise_amount_cents:    gross amount minus tax-reducing discount allocations
    # position:                            line position on the transaction (tie-break order)
    Line = Struct.new(:id, :tax_category_id, :direction, :taxable_merchandise_amount_cents, :position,
                       keyword_init: true)

    # Mirrors the pos_line_item_taxes snapshot fields from docs/implementation/phase-04-tax-schema.md.
    ComponentResult = Struct.new(
      :store_tax_rule_id, :store_tax_rate_id, :tax_category_id, :treatment_snapshot,
      :receipt_code_snapshot, :component_code, :calculation_order, :compounds_on_prior_tax_snapshot,
      :taxable_fraction_snapshot, :rate, :position, :taxable_amount_cents, :amount_cents,
      keyword_init: true
    )

    ExemptComponentResult = Struct.new(
      :store_tax_rule_id, :tax_category_id, :component_code, :treatment_snapshot, keyword_init: true
    )

    LineResult = Struct.new(
      :line_id, :tax_category_id, :direction, :position, :taxable_merchandise_amount_cents,
      :components, :exempt_components, :tax_amount_cents, keyword_init: true
    )

    class Result
      attr_reader :lines, :warnings, :blockers, :total_tax_cents_by_direction

      def initialize(lines:, warnings:, blockers:, total_tax_cents_by_direction:)
        @lines = lines
        @warnings = warnings
        @blockers = blockers
        @total_tax_cents_by_direction = total_tax_cents_by_direction
      end

      def success?
        blockers.empty?
      end
    end

    def initialize(store:, lines:, completion_date: nil)
      @store = store
      @lines = lines.map { |line| line.is_a?(Line) ? line : Line.new(**line) }
      @completion_date = completion_date || store_local_today
      @rules_cache = {}
    end

    def call
      warnings = []
      blockers = []
      line_results = []

      @lines.each do |line|
        unless DIRECTIONS.include?(line.direction)
          raise ArgumentError, "unsupported tax direction #{line.direction.inspect} for line #{line.id}"
        end

        warnings << "Line #{line.id} has a negative taxable merchandise amount" if line.taxable_merchandise_amount_cents.negative?
      end

      @lines.group_by(&:direction).each do |direction, direction_lines|
        line_results.concat(calculate_direction(direction, direction_lines, blockers))
      end

      totals = line_results.group_by(&:direction).transform_values { |results| results.sum(&:tax_amount_cents) }

      Result.new(
        lines: line_results.sort_by(&:position),
        warnings: warnings,
        blockers: blockers,
        total_tax_cents_by_direction: totals
      )
    end

    private

    def calculate_direction(direction, direction_lines, blockers)
      rules_by_line = {}
      direction_lines.each do |line|
        rules = effective_rules_for(line.tax_category_id)
        if rules.empty?
          blockers << "No effective store tax rule for tax_category_id=#{line.tax_category_id} " \
                      "(line #{line.id}, #{direction})"
        end
        rules_by_line[line.id] = rules
      end

      component_groups = build_component_groups(direction_lines, rules_by_line)
      ordered_keys = component_groups.keys.sort_by { |key| [ key[1], key[0].to_i ] }

      taxable_amount_by_line_component = {}
      amount_by_line_component = {}
      finalized_tax_by_line = Hash.new(0)

      ordered_keys.each do |key|
        group = component_groups[key]
        rule = group[:rule]
        rate = rule.store_tax_rate.rate

        taxable_items = group[:entries].map do |entry|
          line = entry[:line]
          exact_cents = BigDecimal(line.taxable_merchandise_amount_cents) * rule.taxable_fraction
          { key: line.id, exact_cents: exact_cents, position: line.position, id: line.id }
        end
        taxable_allocation = allocate_largest_remainder(taxable_items, round_half_up(sum_exact(taxable_items)))

        tax_items = group[:entries].map do |entry|
          line = entry[:line]
          base = taxable_allocation.fetch(line.id)
          base += finalized_tax_by_line[line.id] if rule.compounds_on_prior_tax
          exact_cents = BigDecimal(base) * rate
          { key: line.id, exact_cents: exact_cents, position: line.position, id: line.id }
        end
        tax_allocation = allocate_largest_remainder(tax_items, round_half_up(sum_exact(tax_items)))

        group[:entries].each do |entry|
          line = entry[:line]
          amount_cents = tax_allocation.fetch(line.id)
          finalized_tax_by_line[line.id] += amount_cents
          taxable_amount_by_line_component[[ line.id, rule.id ]] = taxable_allocation.fetch(line.id)
          amount_by_line_component[[ line.id, rule.id ]] = amount_cents
        end
      end

      direction_lines.map do |line|
        rules = rules_by_line[line.id] || []
        components = rules.select { |rule| COMPONENT_TREATMENTS.include?(rule.treatment) }
                           .sort_by { |rule| [ rule.calculation_order, rule.store_tax_rate_id.to_i ] }
                           .each_with_index.map do |rule, index|
          ComponentResult.new(
            store_tax_rule_id: rule.id,
            store_tax_rate_id: rule.store_tax_rate_id,
            tax_category_id: rule.tax_category_id,
            treatment_snapshot: rule.treatment,
            receipt_code_snapshot: rule.store_tax_rate.receipt_code,
            component_code: rule.component_code,
            calculation_order: rule.calculation_order,
            compounds_on_prior_tax_snapshot: rule.compounds_on_prior_tax,
            taxable_fraction_snapshot: rule.taxable_fraction,
            rate: rule.store_tax_rate.rate,
            position: index,
            taxable_amount_cents: taxable_amount_by_line_component.fetch([ line.id, rule.id ], 0),
            amount_cents: amount_by_line_component.fetch([ line.id, rule.id ], 0)
          )
        end

        exempt_components = rules.select { |rule| rule.treatment == "exempt" }.map do |rule|
          ExemptComponentResult.new(
            store_tax_rule_id: rule.id,
            tax_category_id: rule.tax_category_id,
            component_code: rule.component_code,
            treatment_snapshot: "exempt"
          )
        end

        LineResult.new(
          line_id: line.id,
          tax_category_id: line.tax_category_id,
          direction: direction,
          position: line.position,
          taxable_merchandise_amount_cents: line.taxable_merchandise_amount_cents,
          components: components,
          exempt_components: exempt_components,
          tax_amount_cents: components.sum(&:amount_cents)
        )
      end
    end

    # Groups (line, rule) pairs into transaction tax components identified by
    # store_tax_rate_id + calculation_order + compounds_on_prior_tax (ADR-0014). Exempt
    # rules never form a component: exempt treatment collects no tax and creates no row.
    def build_component_groups(direction_lines, rules_by_line)
      groups = {}
      direction_lines.each do |line|
        (rules_by_line[line.id] || []).each do |rule|
          next unless COMPONENT_TREATMENTS.include?(rule.treatment)

          key = [ rule.store_tax_rate_id, rule.calculation_order, rule.compounds_on_prior_tax ]
          groups[key] ||= { rule: rule, entries: [] }
          groups[key][:entries] << { line: line, rule: rule }
        end
      end
      groups
    end

    def effective_rules_for(tax_category_id)
      @rules_cache[tax_category_id] ||= StoreTaxRule
        .where(store_id: @store.id, tax_category_id: tax_category_id, active: true)
        .where("effective_from IS NULL OR effective_from <= ?", @completion_date)
        .where("effective_to IS NULL OR effective_to >= ?", @completion_date)
        .includes(:store_tax_rate)
        .to_a
    end

    def sum_exact(items)
      items.sum(BigDecimal("0")) { |item| item[:exact_cents] }
    end

    def round_half_up(decimal)
      decimal.round(0, half: :up).to_i
    end

    # Largest-remainder allocation (ADR-0014): floor each exact share, then distribute the
    # residual cents to the items with the largest fractional remainder, tie-broken by
    # ascending position then ascending id.
    def allocate_largest_remainder(items, rounded_total)
      allocations = {}
      remainders = items.map do |item|
        floor = item[:exact_cents].floor.to_i
        allocations[item[:key]] = floor
        { key: item[:key], remainder: item[:exact_cents] - floor, position: item[:position], id: item[:id] }
      end

      residual = rounded_total - allocations.values.sum
      return allocations if residual.zero?

      ordered = remainders.sort_by { |r| [ -r[:remainder], r[:position], r[:id] ] }

      if residual.positive?
        ordered.first(residual).each { |r| allocations[r[:key]] += 1 }
      else
        ordered.reverse.first(-residual).each { |r| allocations[r[:key]] -= 1 }
      end

      allocations
    end

    def store_local_today
      zone_name = @store&.timezone.presence || Time.zone.name
      Time.find_zone!(zone_name).today
    end
  end
end
