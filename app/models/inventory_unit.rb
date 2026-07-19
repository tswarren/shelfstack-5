# frozen_string_literal: true

# One exact physical copy of an individually tracked Product Variant
# (ADR-0001). Carries its own generated `27` Unit Identifier and exact
# acquisition cost, distinct from the Store-and-Variant moving average used
# for quantity-tracked merchandise.
class InventoryUnit < ApplicationRecord
  # Phase 4 baseline statuses; `rtv`/`in_transfer` are reserved-but-unimplemented
  # per docs/implementation/deferred-capabilities.md (no transfer/RTV document
  # workflow exists yet — do not build one from this enum value alone).
  STATUSES = %w[available reserved sold inspection damaged discarded rtv in_transfer].freeze
  ACQUISITION_SOURCE_TYPES = %w[receipt_line return_line buyback adjustment other].freeze

  belongs_to :store
  belongs_to :product_variant
  belongs_to :product_condition, optional: true
  belongs_to :created_by_user, class_name: "User"
  belongs_to :sold_pos_line_item, class_name: "PosLineItem", optional: true
  has_many :inventory_reservations, dependent: :restrict_with_exception
  has_many :pos_line_items, dependent: :restrict_with_exception

  attr_readonly :unit_identifier

  validates :unit_identifier, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :acquired_at, presence: true
  validates :acquisition_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :acquisition_source_type, inclusion: { in: ACQUISITION_SOURCE_TYPES }, allow_nil: true
  validate :store_and_variant_same_organization
  validate :individually_tracked_variant
  validate :unit_identifier_is_generated_27
  validate :sold_state_matches_sold_line

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

  def sold_state_matches_sold_line
    if status == "sold"
      errors.add(:sold_pos_line_item, "is required when status is sold") if sold_pos_line_item_id.blank?
    elsif sold_pos_line_item_id.present?
      errors.add(:sold_pos_line_item, "must be blank unless status is sold")
    end
  end
end
