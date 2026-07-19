# frozen_string_literal: true

# Persisted ADR-0014 hybrid tax-component snapshot for a pending POS line, written by
# Pos::RecalculateTransaction from Tax::CalculateTransaction results. Only `taxable`
# and `zero_rated` treatments create rows; `exempt` collects no tax and is not
# persisted here (see Tax::CalculateTransaction).
class PosLineItemTax < ApplicationRecord
  TREATMENTS = %w[taxable zero_rated exempt].freeze

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
