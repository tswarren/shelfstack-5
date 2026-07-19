# frozen_string_literal: true

# Deterministic per-line share of a POS Discount, computed with the same
# largest-remainder family used elsewhere for cent allocation (ADR-0014).
class PosDiscountAllocation < ApplicationRecord
  belongs_to :pos_discount
  belongs_to :pos_line_item

  validates :allocated_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :pos_line_item_id, uniqueness: { scope: :pos_discount_id }
end
