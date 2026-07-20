# frozen_string_literal: true

class InventoryAdjustmentLine < ApplicationRecord
  COST_METHODS = %w[explicit configured_estimate moving_average unknown].freeze
  COST_QUALITIES = %w[actual estimated mixed unknown].freeze
  OPENING_METHODS = %w[explicit configured_estimate unknown].freeze
  OPENING_KNOWN_QUALITIES = %w[actual estimated].freeze
  CORRECTION_METHODS = %w[explicit].freeze
  CORRECTION_QUALITIES = %w[actual estimated mixed].freeze

  # Presentation-only values for invalid money redisplay (not persisted).
  attr_accessor :input_unit_cost_input, :corrected_inventory_value_input

  belongs_to :inventory_adjustment
  belongs_to :product_variant
  belongs_to :estimate_department, class_name: "Department", optional: true

  validates :product_variant_id, uniqueness: { scope: :inventory_adjustment_id }
  validates :position, numericality: { only_integer: true }
  validates :quantity_delta, numericality: { only_integer: true }
  validates :input_unit_cost_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :corrected_inventory_value_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :input_cost_method, inclusion: { in: COST_METHODS }, allow_nil: true
  validates :input_cost_quality, inclusion: { in: COST_QUALITIES }, allow_nil: true
  validate :variant_matches_organization
  validate :quantity_tracked_variant
  validate :kind_specific_inputs
  validate :cost_state_combinations

  before_update :require_draft_parent
  before_destroy :require_draft_parent

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
    when "opening_inventory"
      errors.add(:quantity_delta, "must be positive for opening inventory") unless quantity_delta.to_i.positive?
      if corrected_inventory_value_cents.present?
        errors.add(:corrected_inventory_value_cents, "must be blank for opening inventory")
      end
    when "quantity_only"
      errors.add(:quantity_delta, "must be non-zero for quantity-only adjustments") if quantity_delta.to_i.zero?
      if corrected_inventory_value_cents.present?
        errors.add(:corrected_inventory_value_cents, "must be blank for quantity-only adjustments")
      end
      if input_unit_cost_cents.present? || input_cost_method.present? || input_cost_quality.present?
        errors.add(:base, "quantity-only lines cannot include cost inputs")
      end
    when "cost_correction"
      errors.add(:quantity_delta, "must be zero for cost corrections") unless quantity_delta.to_i.zero?
      if input_unit_cost_cents.present?
        errors.add(:input_unit_cost_cents, "must be blank for cost corrections; use corrected aggregate value")
      end
    end
  end

  def cost_state_combinations
    return if inventory_adjustment.blank?

    case inventory_adjustment.kind
    when "opening_inventory"
      validate_opening_cost_state
    when "cost_correction"
      validate_cost_correction_state
    end
  end

  def validate_opening_cost_state
    method = input_cost_method.to_s.presence
    quality = input_cost_quality.to_s.presence

    if method.present? && OPENING_METHODS.exclude?(method)
      errors.add(:input_cost_method, "is not valid for opening inventory")
    end

    if method == "configured_estimate"
      errors.add(:input_unit_cost_cents, "must be blank when using configured estimate") if input_unit_cost_cents.present?
    elsif method == "unknown"
      errors.add(:input_unit_cost_cents, "must be blank when cost is unknown") if input_unit_cost_cents.present?
      if quality.present? && quality != "unknown"
        errors.add(:input_cost_quality, "must be unknown when cost method is unknown")
      end
    elsif input_unit_cost_cents.present?
      if method.present? && method != "explicit"
        errors.add(:input_cost_method, "must be explicit when a unit cost is supplied")
      end
      if quality.present? && OPENING_KNOWN_QUALITIES.exclude?(quality)
        errors.add(:input_cost_quality, "must be actual or estimated when a unit cost is supplied")
      end
    end
  end


  def validate_cost_correction_state
    method = input_cost_method.to_s.presence || "explicit"
    quality = input_cost_quality.to_s.presence

    if corrected_inventory_value_cents.nil?
      errors.add(:corrected_inventory_value_cents, "is required for cost corrections")
    end

    unless CORRECTION_METHODS.include?(method)
      errors.add(:input_cost_method, "must be explicit for Phase 3 cost corrections")
    end

    if quality.blank?
      # defaulted at post to actual
    elsif CORRECTION_QUALITIES.exclude?(quality)
      errors.add(:input_cost_quality, "must be actual, estimated, or mixed for cost corrections")
    end
  end


  def require_draft_parent
    return if inventory_adjustment&.draft?

    errors.add(:base, "lines can only be changed while the adjustment is draft")
    throw(:abort)
  end
end
