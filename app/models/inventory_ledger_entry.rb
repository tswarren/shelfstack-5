# frozen_string_literal: true

class InventoryLedgerEntry < ApplicationRecord
  MOVEMENT_TYPES = %w[opening_inventory quantity_adjustment cost_correction].freeze
  COST_METHODS = %w[explicit configured_estimate moving_average unknown].freeze
  COST_QUALITIES = %w[actual estimated mixed unknown].freeze

  belongs_to :store
  belongs_to :product_variant
  belongs_to :posted_by_user, class_name: "User"
  belongs_to :reversal_of_entry, class_name: "InventoryLedgerEntry", optional: true
  belongs_to :estimate_department, class_name: "Department", optional: true
  belongs_to :source, polymorphic: true

  attr_readonly :posting_key, :quantity_delta, :inventory_value_delta_cents, :movement_type

  validates :movement_type, presence: true, inclusion: { in: MOVEMENT_TYPES }
  validates :quantity_delta, presence: true, numericality: { only_integer: true }
  validates :cost_method, presence: true, inclusion: { in: COST_METHODS }
  validates :cost_quality, presence: true, inclusion: { in: COST_QUALITIES }
  validates :resulting_cost_quality, presence: true, inclusion: { in: COST_QUALITIES }
  validates :posting_key, presence: true, uniqueness: true
  validates :posted_at, presence: true
  validate :store_and_variant_same_organization

  before_destroy :prevent_destroy

  private

  def store_and_variant_same_organization
    return if store.blank? || product_variant.blank?
    return if store.organization_id == product_variant.organization.id

    errors.add(:base, "store and product variant must belong to the same organization")
  end

  def prevent_destroy
    errors.add(:base, "inventory ledger entries are append-only")
    throw(:abort)
  end
end
