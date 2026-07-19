# frozen_string_literal: true

# Persisted ADR-0014 hybrid tax-component snapshot for a pending POS line, written by
# Pos::RecalculateTransaction from Tax::CalculateTransaction results. Collecting
# treatments (`taxable`, `zero_rated`) carry amounts; non-collecting treatments
# (`exempt`, `not_applicable`) are snapshotted at $0 for audit/reporting.
class PosLineItemTax < ApplicationRecord
  TREATMENTS = %w[taxable zero_rated exempt not_applicable].freeze

  belongs_to :pos_line_item
  belongs_to :store_tax_rule
  belongs_to :store_tax_rate, optional: true
  belongs_to :tax_category

  validates :treatment_snapshot, presence: true, inclusion: { in: TREATMENTS }
  validates :taxable_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :taxable_fraction_snapshot, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
