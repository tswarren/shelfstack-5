# frozen_string_literal: true

class InventoryAdjustment < ApplicationRecord
  KINDS = %w[opening_inventory quantity_only cost_correction].freeze
  STATUSES = %w[draft posted cancelled].freeze

  belongs_to :store
  belongs_to :inventory_adjustment_reason
  belongs_to :created_by_user, class_name: "User"
  belongs_to :posted_by_user, class_name: "User", optional: true
  belongs_to :cancelled_by_user, class_name: "User", optional: true
  has_many :inventory_adjustment_lines, dependent: :restrict_with_exception
  accepts_nested_attributes_for :inventory_adjustment_lines, allow_destroy: false

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :inventory_adjustment_reason, presence: true
  validate :reason_matches_kind_and_organization
  validate :note_required_when_posted_and_reason_requires_note

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

  def qualified_reason_code
    return if reason_code_snapshot.blank?

    "#{kind}.#{reason_code_snapshot}"
  end

  private

  def reason_matches_kind_and_organization
    return if inventory_adjustment_reason.blank? || store.blank?

    if inventory_adjustment_reason.organization_id != store.organization_id
      errors.add(:inventory_adjustment_reason, "must belong to the same organization as the store")
    end

    if inventory_adjustment_reason.adjustment_kind != kind
      errors.add(:inventory_adjustment_reason, "must match the adjustment kind")
    end
  end

  def note_required_when_posted_and_reason_requires_note
    return unless status == "posted"
    return if inventory_adjustment_reason.blank?
    return unless inventory_adjustment_reason.requires_note?
    return if note.present?

    errors.add(:note, "is required for this reason")
  end
end
