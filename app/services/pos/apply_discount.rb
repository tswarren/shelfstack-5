# frozen_string_literal: true

require "bigdecimal"

module Pos
  # Applies a line- or transaction-scoped Discount and allocates it deterministically
  # among eligible lines using the same largest-remainder family used elsewhere for
  # cent allocation (ADR-0014's "same deterministic residual family as other money
  # allocations"). Ordinary discounts default to `tax_treatment: reduces_taxable_base`.
  class ApplyDiscount < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_discount, :success?, :error, :warnings, :pos_approval)

    def initialize(pos_transaction:, scope:, method:, actor:, pos_line_item: nil, rate_bps: nil, amount_cents: nil,
                    tax_treatment: "reduces_taxable_base", discount_reason: nil, reason: nil,
                    approver: nil, approver_pin: nil)
      @pos_transaction = pos_transaction
      @scope = scope.to_s
      @method = method.to_s
      @pos_line_item = pos_line_item
      @rate_bps = rate_bps
      @amount_cents = amount_cents
      @tax_treatment = tax_treatment.to_s
      @discount_reason = discount_reason
      @reason = reason
      @actor = actor
      @approver = approver
      @approver_pin = approver_pin
    end

    def call
      raise Error, "transaction is not open for editing" unless @pos_transaction.editable?
      raise Error, "unsupported scope" unless PosDiscount::SCOPES.include?(@scope)
      raise Error, "unsupported method" unless PosDiscount::METHODS.include?(@method)
      raise Error, "unsupported tax treatment" unless PosDiscount::TAX_TREATMENTS.include?(@tax_treatment)

      store = @pos_transaction.store

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        # Canonical order: transaction lock first, then affected lines.
        if @scope == "line"
          raise Error, "line is required for line-scoped discounts" if @pos_line_item.blank?
          locked_line = PosLineItem.lock.find(@pos_line_item.id)
          raise Error, "line does not belong to this transaction" unless locked_line.pos_transaction_id == transaction.id
          @pos_line_item = locked_line
        else
          transaction.pos_line_items.pending.sales.lock.order(:position, :id).load
        end

        eligible_lines = resolve_eligible_lines(transaction)
        raise Error, "no eligible pending lines to discount" if eligible_lines.empty?

        remaining_by_line = remaining_discountable_cents_by_line(eligible_lines)
        eligible_lines = eligible_lines.select { |line| remaining_by_line.fetch(line.id).positive? }
        raise Error, "no remaining discountable amount on eligible lines" if eligible_lines.empty?

        base_amount_cents = eligible_lines.sum { |line| remaining_by_line.fetch(line.id) }
        raise Error, "nothing to discount" unless base_amount_cents.positive?

        applied_amount_cents = compute_applied_amount_cents(base_amount_cents)

        authorization = Pos::AuthorizeAction.call(
          store: store,
          requester: @actor,
          permission_key: "pos.discount.apply",
          approver_permission_key: "pos.discount.approve",
          action_type: "discount_apply",
          limit_key: authority_limit_key,
          requested_value: authority_requested_value(applied_amount_cents),
          reason: @reason,
          approver: @approver,
          approver_pin: @approver_pin,
          pos_transaction: transaction,
          pos_line_item: @scope == "line" ? @pos_line_item : nil,
          pos_session: transaction.active_pos_session
        )
        unless authorization.allowed?
          raise Error, unauthorized_message(authorization)
        end

        discount = PosDiscount.create!(
          pos_transaction: transaction,
          target_pos_line_item: @scope == "line" ? @pos_line_item : nil,
          scope: @scope,
          method: @method,
          tax_treatment: @tax_treatment,
          position: next_position(transaction),
          base_amount_cents: base_amount_cents,
          rate_bps: @method == "percentage" ? @rate_bps.to_i : nil,
          requested_amount_cents: @method == "percentage" ? nil : @amount_cents.to_i,
          applied_amount_cents: applied_amount_cents,
          discount_reason: @discount_reason,
          created_by_user: @actor,
          created_at: Time.current
        )

        allocate!(discount, eligible_lines, applied_amount_cents, remaining_by_line)

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "pos_discount.applied",
          subject: discount,
          metadata: {
            "scope" => @scope,
            "method" => @method,
            "applied_amount_cents" => applied_amount_cents,
            "approved_by_user_id" => authorization.pos_approval&.approved_by_user_id
          }
        )

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)

        Result.new(pos_discount: discount, success?: true, error: nil,
                   warnings: recalculation.blockers + recalculation.warnings, pos_approval: authorization.pos_approval)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_discount: nil, success?: false, error: e.message, warnings: [], pos_approval: nil)
    end

    private

    def resolve_eligible_lines(transaction = @pos_transaction)
      case @scope
      when "line"
        raise Error, "line is required for line-scoped discounts" if @pos_line_item.blank?
        raise Error, "line does not belong to this transaction" unless @pos_line_item.pos_transaction_id == transaction.id
        raise Error, "line is not pending" unless @pos_line_item.pending?
        raise Error, "cannot discount a linked return line" if @pos_line_item.return?
        raise Error, "cannot discount a stored-value line" if @pos_line_item.line_kind == "stored_value"

        [ @pos_line_item ]
      when "transaction"
        transaction.pos_line_items.pending.sales.order(:position, :id)
          .reject { |line| line.line_kind == "stored_value" }
      else
        []
      end
    end

    def compute_applied_amount_cents(base_amount_cents)
      case @method
      when "percentage"
        raise Error, "rate_bps must be between 0 and 10000" unless @rate_bps.to_i.between?(0, 10_000)

        exact = BigDecimal(base_amount_cents) * BigDecimal(@rate_bps.to_i) / BigDecimal(10_000)
        clamp(exact.round(0, half: :up).to_i, base_amount_cents)
      when "fixed_amount"
        raise Error, "amount_cents must not be negative" if @amount_cents.to_i.negative?

        clamp(@amount_cents.to_i, base_amount_cents)
      when "fixed_price"
        raise Error, "fixed_price discounts must be line-scoped" unless @scope == "line"
        raise Error, "amount_cents (target price) must not be negative" if @amount_cents.to_i.negative?
        raise Error, "target price must not exceed the line's gross amount" if @amount_cents.to_i > base_amount_cents

        base_amount_cents - @amount_cents.to_i
      end
    end

    def clamp(value, max)
      [ [ value, 0 ].max, max ].min
    end

    def authority_limit_key
      @method == "percentage" ? :maximum_discount_rate : :maximum_discount_amount_cents
    end

    def authority_requested_value(applied_amount_cents)
      if @method == "percentage"
        BigDecimal(@rate_bps.to_i) / BigDecimal(10_000)
      else
        applied_amount_cents
      end
    end

    def next_position(transaction)
      (transaction.pos_discounts.maximum(:position) || -1) + 1
    end

    # Largest-remainder allocation proportional to each eligible line's *remaining*
    # discountable amount (gross − prior allocations). Tie-break: remainder
    # descending, then line position ascending, then line id ascending (ADR-0014 family).
    def allocate!(discount, eligible_lines, applied_amount_cents, remaining_by_line)
      total_eligible = eligible_lines.sum { |line| remaining_by_line.fetch(line.id) }
      now = Time.current

      shares = eligible_lines.map do |line|
        remaining = remaining_by_line.fetch(line.id)
        exact = total_eligible.zero? ? BigDecimal(0) : BigDecimal(applied_amount_cents) * BigDecimal(remaining) / BigDecimal(total_eligible)
        { line: line, remaining: remaining, exact: exact, floor: exact.floor.to_i }
      end

      allocated_floor_total = shares.sum { |s| s[:floor] }
      residual = applied_amount_cents - allocated_floor_total

      ordered = shares.sort_by { |s| [ -(s[:exact] - s[:floor]), s[:line].position, s[:line].id ] }
      ordered.first(residual).each { |s| s[:floor] += 1 } if residual.positive?

      shares.each do |s|
        raise Error, "discount allocation exceeds remaining capacity for a line" if s[:floor] > s[:remaining]

        PosDiscountAllocation.create!(
          pos_discount: discount,
          pos_line_item: s[:line],
          eligible_amount_cents: s[:remaining],
          allocated_amount_cents: s[:floor],
          created_at: now
        )
      end
    end

    def remaining_discountable_cents_by_line(lines)
      already = PosDiscountAllocation.where(pos_line_item_id: lines.map(&:id))
                                     .group(:pos_line_item_id)
                                     .sum(:allocated_amount_cents)
      lines.each_with_object({}) do |line, hash|
        hash[line.id] = [ line.extended_price_cents - already.fetch(line.id, 0), 0 ].max
      end
    end

    def unauthorized_message(authorization)
      case authorization.status
      when :requires_approval then "discount exceeds authority and requires approval"
      else authorization.error || "discount denied"
      end
    end

    def unauthorized_result(authorization)
      Result.new(pos_discount: nil, success?: false, error: unauthorized_message(authorization),
                 warnings: [], pos_approval: nil)
    end
  end
end
