# frozen_string_literal: true

module Pos
  # One-shot grouped discount/tax cents by line for GET-safe POS workspace rendering.
  class LineFinancialSnapshots < ApplicationService
    Result = Data.define(:discount_cents_by_id, :tax_cents_by_id)

    def initialize(pos_line_item_ids:)
      @pos_line_item_ids = Array(pos_line_item_ids).compact
    end

    def call
      return Result.new(discount_cents_by_id: {}, tax_cents_by_id: {}) if @pos_line_item_ids.empty?

      discount = PosDiscountAllocation
        .where(pos_line_item_id: @pos_line_item_ids)
        .group(:pos_line_item_id)
        .sum(:allocated_amount_cents)
      tax = PosLineItemTax
        .where(pos_line_item_id: @pos_line_item_ids)
        .group(:pos_line_item_id)
        .sum(:amount_cents)

      Result.new(discount_cents_by_id: discount, tax_cents_by_id: tax)
    end
  end
end
