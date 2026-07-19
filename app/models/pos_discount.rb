# frozen_string_literal: true

# Price Override is distinct from Discount (see Pos::OverridePrice); a POS Discount
# always carries an explicit tax_treatment so Tax::CalculateTransaction knows whether
# the allocation reduces the taxable merchandise amount (ADR-0014).
class PosDiscount < ApplicationRecord
  SCOPES = %w[line transaction].freeze
  METHODS = %w[percentage fixed_amount fixed_price].freeze
  TAX_TREATMENTS = %w[reduces_taxable_base does_not_reduce_taxable_base].freeze

  belongs_to :pos_transaction
  belongs_to :target_pos_line_item, class_name: "PosLineItem", optional: true
  belongs_to :discount_reason, optional: true
  belongs_to :created_by_user, class_name: "User"
  has_many :pos_discount_allocations, dependent: :restrict_with_exception

  validates :scope, presence: true, inclusion: { in: SCOPES }
  validates :method, presence: true, inclusion: { in: METHODS }
  validates :tax_treatment, presence: true, inclusion: { in: TAX_TREATMENTS }
  validates :applied_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :target_line_matches_scope

  def reduces_taxable_base?
    tax_treatment == "reduces_taxable_base"
  end

  private

  def target_line_matches_scope
    if scope == "line" && target_pos_line_item.blank?
      errors.add(:target_pos_line_item, "is required for line-scoped discounts")
    elsif scope == "transaction" && target_pos_line_item.present?
      errors.add(:target_pos_line_item, "must be blank for transaction-scoped discounts")
    end
  end
end
