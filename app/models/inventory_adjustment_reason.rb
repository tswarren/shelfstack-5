# frozen_string_literal: true

class InventoryAdjustmentReason < ApplicationRecord
  ADJUSTMENT_KINDS = %w[opening_inventory quantity_only cost_correction].freeze

  belongs_to :organization
  has_many :inventory_adjustments, dependent: :restrict_with_exception

  attr_readonly :code, :adjustment_kind

  validates :adjustment_kind, presence: true, inclusion: { in: ADJUSTMENT_KINDS }
  validates :code, presence: true, uniqueness: { scope: [ :organization_id, :adjustment_kind ] }
  validates :name, presence: true
  validates :requires_note, inclusion: { in: [ true, false ] }
  validates :active, inclusion: { in: [ true, false ] }
  validates :position, numericality: { only_integer: true }

  scope :ordered, -> { order(:adjustment_kind, :position, :name) }
  scope :active, -> { where(active: true) }
  scope :for_kind, ->(kind) { where(adjustment_kind: kind) }

  def qualified_code
    "#{adjustment_kind}.#{code}"
  end
end
