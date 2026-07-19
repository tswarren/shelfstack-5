# frozen_string_literal: true

class InventoryReservation < ApplicationRecord
  STATUSES = %w[active released converted].freeze
  SOURCE_TYPES = %w[pos_line_item product_request].freeze
  RESERVABLE_TRACKING_MODES = %w[quantity individual].freeze

  belongs_to :store
  belongs_to :product_variant
  belongs_to :inventory_unit, optional: true
  belongs_to :released_by_user, class_name: "User", optional: true

  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :source_id, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reserved_at, presence: true
  validate :store_and_variant_same_organization
  validate :reservable_variant_mode
  validate :individual_reservation_shape

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  private

  def store_and_variant_same_organization
    return if store.blank? || product_variant.blank?
    return if store.organization_id == product_variant.organization.id

    errors.add(:base, "store and product variant must belong to the same organization")
  end

  def reservable_variant_mode
    return if product_variant.blank?
    return if RESERVABLE_TRACKING_MODES.include?(product_variant.inventory_tracking_mode)

    errors.add(:product_variant, "must use quantity or individual inventory tracking")
  end

  # ADR-0006: "an individually tracked reservation identifies the exact
  # inventory unit"; a quantity-tracked reservation never carries a Unit.
  def individual_reservation_shape
    return if product_variant.blank?

    if product_variant.inventory_tracking_mode == "individual"
      if inventory_unit.blank?
        errors.add(:inventory_unit, "is required for individually tracked reservations")
      else
        errors.add(:inventory_unit, "must match the same store") if inventory_unit.store_id != store_id
        errors.add(:inventory_unit, "must match the same product variant") if inventory_unit.product_variant_id != product_variant_id
      end
      errors.add(:quantity, "must be 1 for individually tracked reservations") if quantity.present? && quantity != 1
    elsif inventory_unit.present?
      errors.add(:inventory_unit, "must be blank for quantity-tracked reservations")
    end
  end
end
