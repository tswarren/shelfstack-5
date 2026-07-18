# frozen_string_literal: true

class InventoryAdjustmentLine < ApplicationRecord
  COST_METHODS = %w[explicit configured_estimate moving_average unknown].freeze
  COST_QUALITIES = %w[actual estimated mixed unknown].freeze

  belongs_to :inventory_adjustment
  belongs_to :product_variant
  belongs_to :estimate_department, class_name: "Department", optional: true

  validates :product_variant_id, uniqueness: { scope: :inventory_adjustment_id }
  validates :position, numericality: { only_integer: true }
  validates :quantity_delta, numericality: { only_integer: true }
  validates :input_cost_method, inclusion: { in: COST_METHODS }, allow_nil: true
  validates :input_cost_quality, inclusion: { in: COST_QUALITIES }, allow_nil: true
  validate :variant_matches_organization
  validate :quantity_tracked_variant
  validate :kind_specific_inputs

  private

  def variant_matches_organization
    return if inventory_adjustment.blank? || product_variant.blank?

    if product_variant.organization.id != inventory_adjustment.store.organization_id
      errors.add(:product_variant, "must belong to the same organization as the adjustment store")
    end
  end

  def quantity_tracked_variant
    return if product_variant.blank?
    return if product_variant.inventory_tracking_mode == "quantity"

    errors.add(:product_variant, "must use quantity inventory tracking")
  end

  def kind_specific_inputs
    return if inventory_adjustment.blank?

    case inventory_adjustment.kind
    when "cost_correction"
      if quantity_delta != 0
        errors.add(:quantity_delta, "must be zero for cost corrections")
      end
    when "quantity_only"
      if corrected_inventory_value_cents.present?
        errors.add(:corrected_inventory_value_cents, "must be blank for quantity-only adjustments")
      end
    end
  end
end
