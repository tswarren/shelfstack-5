# frozen_string_literal: true

class InventoryReservation < ApplicationRecord
  STATUSES = %w[active released converted].freeze
  SOURCE_TYPES = %w[pos_line_item product_request].freeze

  belongs_to :store
  belongs_to :product_variant
  belongs_to :released_by_user, class_name: "User", optional: true

  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :source_id, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reserved_at, presence: true
  validate :store_and_variant_same_organization
  validate :quantity_tracked_variant

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

  def quantity_tracked_variant
    return if product_variant.blank?
    return if product_variant.inventory_tracking_mode == "quantity"

    errors.add(:product_variant, "must use quantity inventory tracking")
  end
end
