# frozen_string_literal: true

# One exact physical copy of an individually tracked Product Variant
# (ADR-0001). Carries its own generated `27` Unit Identifier and exact
# acquisition cost, distinct from the Store-and-Variant moving average used
# for quantity-tracked merchandise.
class InventoryUnit < ApplicationRecord
  STATUSES = %w[available reserved sold].freeze

  belongs_to :store
  belongs_to :product_variant
  belongs_to :product_condition, optional: true
  belongs_to :created_by_user, class_name: "User"
  has_many :inventory_reservations, dependent: :restrict_with_exception
  has_many :pos_line_items, dependent: :restrict_with_exception

  attr_readonly :unit_identifier

  validates :unit_identifier, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :acquired_at, presence: true
  validates :acquisition_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :store_and_variant_same_organization
  validate :individually_tracked_variant
  validate :unit_identifier_is_generated_27

  scope :available, -> { where(status: "available") }

  def available?
    status == "available"
  end

  def reserved?
    status == "reserved"
  end

  def sold?
    status == "sold"
  end

  private

  def store_and_variant_same_organization
    return if store.blank? || product_variant.blank?
    return if store.organization_id == product_variant.organization.id

    errors.add(:base, "store and product variant must belong to the same organization")
  end

  def individually_tracked_variant
    return if product_variant.blank?
    return if product_variant.inventory_tracking_mode == "individual"

    errors.add(:product_variant, "must use individual inventory tracking")
  end

  def unit_identifier_is_generated_27
    return if unit_identifier.blank?

    normalized = Identifiers::Normalize.call(unit_identifier)
    return if normalized.type == :generated_27 && normalized.validation_status == :valid

    errors.add(:unit_identifier, "must be a valid generated namespace 27 EAN-13")
  end
end
