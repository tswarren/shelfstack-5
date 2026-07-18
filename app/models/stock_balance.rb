# frozen_string_literal: true

class StockBalance < ApplicationRecord
  COST_QUALITIES = %w[actual estimated mixed unknown].freeze

  belongs_to :store
  belongs_to :product_variant

  validates :on_hand, numericality: { only_integer: true }
  validates :reserved, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :unavailable, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cost_quality, presence: true, inclusion: { in: COST_QUALITIES }
  validates :last_known_cost_quality, inclusion: { in: COST_QUALITIES }, allow_nil: true
  validates :product_variant_id, uniqueness: { scope: :store_id }
  validate :store_and_variant_same_organization
  validate :quantity_tracked_variant

  def available
    on_hand - reserved - unavailable
  end

  private

  def store_and_variant_same_organization
    return if store.blank? || product_variant.blank?
    return if store.organization_id == product_variant.organization.id

    errors.add(:base, "store and product variant must belong to the same organization")
  end

  def quantity_tracked_variant
    return if product_variant.blank?
    return if product_variant.inventory_tracking_mode == "quantity"

    errors.add(:product_variant, "must use quantity inventory tracking")
  end
end
