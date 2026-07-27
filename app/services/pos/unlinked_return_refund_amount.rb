# frozen_string_literal: true

module Pos
  # Computes merchandise + refunded-tax cents for an unlinked return before
  # no-receipt authority evaluation. Uses the same Tax::CalculateTransaction
  # path as RecalculateTransaction for current_configured_rules.
  class UnlinkedReturnRefundAmount < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:merchandise_cents, :tax_cents, :total_cents, :success?, :error)

    def initialize(
      store:,
      quantity:,
      unit_price_cents:,
      tax_basis:,
      tax_category:,
      explicit_tax_amount_cents: nil
    )
      @store = store
      @quantity = quantity.to_i
      @unit_price_cents = unit_price_cents.to_i
      @tax_basis = tax_basis.to_s
      @tax_category = tax_category
      @explicit_tax_amount_cents = explicit_tax_amount_cents
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "refund unit price must not be negative" if @unit_price_cents.negative?

      merchandise = @quantity * @unit_price_cents
      tax = tax_cents_for(merchandise)
      Result.new(
        merchandise_cents: merchandise,
        tax_cents: tax,
        total_cents: merchandise + tax,
        success?: true,
        error: nil
      )
    rescue Error => e
      Result.new(
        merchandise_cents: 0,
        tax_cents: 0,
        total_cents: 0,
        success?: false,
        error: e.message
      )
    end

    private

    def tax_cents_for(merchandise)
      case @tax_basis
      when "no_tax_refund"
        0
      when "external_receipt_tax"
        raise Error, "explicit tax amount is required for external receipt tax basis" if @explicit_tax_amount_cents.nil?
        raise Error, "explicit tax amount must not be negative" if @explicit_tax_amount_cents.to_i.negative?

        @explicit_tax_amount_cents.to_i
      when "current_configured_rules"
        raise Error, "tax category is required" if @tax_category.blank?

        calculation = Tax::CalculateTransaction.call(
          store: @store,
          lines: [
            Tax::CalculateTransaction::Line.new(
              id: "unlinked-preview",
              tax_category_id: @tax_category.id,
              direction: "return",
              taxable_merchandise_amount_cents: merchandise,
              position: 0
            )
          ]
        )
        if calculation.blockers.any?
          raise Error, calculation.blockers.join("; ")
        end

        calculation.total_tax_cents_by_direction.fetch("return", 0)
      else
        raise Error, "tax basis is invalid"
      end
    end
  end
end
