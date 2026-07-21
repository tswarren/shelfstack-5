# frozen_string_literal: true

# A Vendor shipment or receiving event at one Store
# (docs/domains/receiving-and-inventory.md#receipt). One shipment may fulfil
# several Purchase Orders, but each is drawn from this Receipt's single Vendor
# (docs/domains/vendors-and-purchasing.md#purchase-order-and-receipt-linkage).
class Receipt < ApplicationRecord
  STATUSES = %w[draft posted cancelled].freeze

  belongs_to :store
  belongs_to :vendor
  belongs_to :received_by_user, class_name: "User", optional: true
  belongs_to :posted_by_user, class_name: "User", optional: true
  belongs_to :cancelled_by_user, class_name: "User", optional: true
  has_many :receipt_lines, dependent: :restrict_with_exception
  # Declared so `form.fields_for :receipt_lines` generates the
  # `_attributes`-suffixed param key `ReceiptsController#lines_params`
  # expects. Lines are actually persisted by `Inventory::CreateReceipt` /
  # `UpdateDraftReceipt`, not by Rails' nested-attributes writer.
  accepts_nested_attributes_for :receipt_lines, allow_destroy: false

  attr_readonly :receipt_number

  validates :receipt_number, presence: true, uniqueness: { scope: :store_id }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :vendor_belongs_to_store_organization

  delegate :organization, to: :store

  scope :draft, -> { where(status: "draft") }

  def draft?
    status == "draft"
  end

  def posted?
    status == "posted"
  end

  def cancelled?
    status == "cancelled"
  end

  private

  def vendor_belongs_to_store_organization
    return if store.blank? || vendor.blank?
    return if store.organization_id == vendor.organization_id

    errors.add(:vendor, "must belong to the same organization as the store")
  end
end
