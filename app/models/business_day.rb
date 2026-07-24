# frozen_string_literal: true

class BusinessDay < ApplicationRecord
  STATUSES = %w[open closed].freeze

  belongs_to :store
  belongs_to :opened_by_user, class_name: "User"
  belongs_to :closed_by_user, class_name: "User", optional: true
  belongs_to :reconciled_by_user, class_name: "User", optional: true
  has_many :pos_sessions, dependent: :restrict_with_exception
  has_one :business_day_z_report, dependent: :restrict_with_exception
  has_one :reconciliation, dependent: :restrict_with_exception
  has_many :pos_close_card_evidences, dependent: :restrict_with_exception

  validates :reporting_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opened_at, presence: true
  validate :reconciled_markers_immutable

  scope :open_days, -> { where(status: "open") }

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end

  private

  def reconciled_markers_immutable
    return unless persisted?
    return if reconciled_at_in_database.blank?

    if will_save_change_to_reconciled_at? && reconciled_at.blank?
      errors.add(:reconciled_at, "cannot be cleared once set")
    end
    if will_save_change_to_reconciled_by_user_id? && reconciled_by_user_id.blank?
      errors.add(:reconciled_by_user, "cannot be cleared once set")
    end
  end
end
