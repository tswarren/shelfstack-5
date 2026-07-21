# frozen_string_literal: true

class PurchaseOrder < ApplicationRecord
  STATUSES = %w[draft ordered closed cancelled].freeze
  FINALIZED_STATUSES = %w[closed cancelled].freeze
  RECEIVING_STATES = %w[not_received partially_received fully_received].freeze

  belongs_to :store
  belongs_to :vendor
  belongs_to :ordered_by_user, class_name: "User", optional: true
  belongs_to :buyer_user, class_name: "User", optional: true
  belongs_to :cancelled_by_user, class_name: "User", optional: true
  belongs_to :closed_by_user, class_name: "User", optional: true
  has_many :purchase_order_lines, dependent: :restrict_with_exception
  has_many :purchase_order_allocations, through: :purchase_order_lines

  attr_readonly :purchase_order_number

  validates :purchase_order_number, presence: true, uniqueness: { scope: :store_id }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :currency_code, presence: true, length: { is: 3 }
  validate :vendor_belongs_to_store_organization
  validate :vendor_active_when_draft

  before_update :prevent_identity_mutation_after_placement

  delegate :organization, to: :store

  scope :draft, -> { where(status: "draft") }
  scope :ordered, -> { where(status: "ordered") }

  def draft?
    status == "draft"
  end

  def ordered?
    status == "ordered"
  end

  def closed?
    status == "closed"
  end

  def cancelled?
    status == "cancelled"
  end

  def finalized?
    FINALIZED_STATUSES.include?(status)
  end

  # Receiving progress is derived from accepted and cancelled quantity; it is
  # never a commercial status (architectural-locks.md#purchase-order-commercial-lifecycle-phase-5).
  def receiving_state
    lines = purchase_order_lines.to_a
    return "not_received" if lines.empty?

    if lines.all? { |line| line.open_quantity.zero? }
      "fully_received"
    elsif lines.any? { |line| line.received_quantity.to_i.positive? }
      "partially_received"
    else
      "not_received"
    end
  end

  private

  def vendor_belongs_to_store_organization
    return if store.blank? || vendor.blank?
    return if store.organization_id == vendor.organization_id

    errors.add(:vendor, "must belong to the same organization as the store")
  end

  def vendor_active_when_draft
    return unless draft?
    return if vendor.blank? || vendor.active?

    errors.add(:vendor, "must be active to create or edit a draft purchase order")
  end

  # Vendor, store, and currency are immutable after placement
  # (architectural-locks.md#purchase-order-commercial-lifecycle-phase-5).
  def prevent_identity_mutation_after_placement
    return if status_in_database == "draft"
    return unless store_id_changed? || vendor_id_changed? || currency_code_changed?

    errors.add(:base, "vendor, store, and currency are immutable after placement")
    throw(:abort)
  end
end
