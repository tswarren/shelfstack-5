# frozen_string_literal: true

module Pos
  # One-shot grouped discount/tax cents by line for GET-safe POS workspace rendering.
  # Every requested line ID is present in the result hashes (default 0) so callers
  # never fall back to per-line association SUMs for missing keys.
  class LineFinancialSnapshots < ApplicationService
    Result = Data.define(:discount_cents_by_id, :tax_cents_by_id)

    def initialize(pos_line_item_ids:)
      @pos_line_item_ids = Array(pos_line_item_ids).compact
    end

    def call
      zeros = @pos_line_item_ids.index_with { 0 }
      return Result.new(discount_cents_by_id: zeros, tax_cents_by_id: zeros.dup) if @pos_line_item_ids.empty?

      discount = zeros.merge(
        PosDiscountAllocation
          .where(pos_line_item_id: @pos_line_item_ids)
          .group(:pos_line_item_id)
          .sum(:allocated_amount_cents)
      )
      tax = zeros.merge(
        PosLineItemTax
          .where(pos_line_item_id: @pos_line_item_ids)
          .group(:pos_line_item_id)
          .sum(:amount_cents)
      )

      Result.new(discount_cents_by_id: discount, tax_cents_by_id: tax)
    end
  end
end
