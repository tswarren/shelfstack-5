# frozen_string_literal: true

# Manual-adjustment reason catalog for Stored Value (Phase 6b), parallel to
# InventoryAdjustmentReason. Every manual adjustment requires an active reason
# (docs/implementation/decisions/phase-06-stored-value-v1-operating-policy.md).
class StoredValueAdjustmentReason < ApplicationRecord
  belongs_to :organization
  has_many :stored_value_entries, dependent: :restrict_with_exception

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :requires_note, inclusion: { in: [ true, false ] }
  validates :active, inclusion: { in: [ true, false ] }
  validates :position, numericality: { only_integer: true }

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(active: true) }
end
