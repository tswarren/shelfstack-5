# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  STATUSES = %w[active inactive discontinued].freeze
  INVENTORY_TRACKING_MODES = %w[quantity individual none].freeze

  belongs_to :product
  belongs_to :default_product_condition, class_name: "ProductCondition", optional: true
  belongs_to :department, optional: true
  belongs_to :tax_category, class_name: "TaxCategory", optional: true
  belongs_to :merchandise_class, optional: true

  attr_readonly :sku

  validates :sku, presence: true, uniqueness: true
  validates :name, presence: true
  validates :inventory_tracking_mode, presence: true, inclusion: { in: INVENTORY_TRACKING_MODES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :sellable, inclusion: { in: [ true, false ] }
  validates :purchasable, inclusion: { in: [ true, false ] }
  validates :regular_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validate :sellable_requires_price

  delegate :organization, to: :product

  private

  def sellable_requires_price
    return unless sellable?
    return if regular_price_cents.present?

    errors.add(:regular_price_cents, "must be present when variant is sellable")
  end
end
