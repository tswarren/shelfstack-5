# frozen_string_literal: true

class PosSession < ApplicationRecord
  STATUSES = %w[open closed].freeze

  belongs_to :business_day
  belongs_to :store
  belongs_to :pos_device
  belongs_to :cash_drawer, optional: true
  belongs_to :cashier_user, class_name: "User"
  belongs_to :opened_by_user, class_name: "User"
  belongs_to :closed_by_user, class_name: "User", optional: true
  belongs_to :reconciled_by_user, class_name: "User", optional: true
  has_one :reconciliation, dependent: :restrict_with_exception
  has_many :pos_transactions, foreign_key: :origin_pos_session_id, inverse_of: :origin_pos_session,
           dependent: :restrict_with_exception
  has_many :active_pos_transactions, class_name: "PosTransaction", foreign_key: :active_pos_session_id,
           inverse_of: :active_pos_session, dependent: :nullify
  has_many :completed_pos_transactions, class_name: "PosTransaction", foreign_key: :completed_pos_session_id,
           inverse_of: :completed_pos_session, dependent: :restrict_with_exception
  has_many :pos_cash_movements, dependent: :restrict_with_exception
  has_many :pos_session_cash_counts, dependent: :restrict_with_exception
  has_one :pos_session_z_report, dependent: :restrict_with_exception
  has_many :pos_close_card_evidences, dependent: :restrict_with_exception

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opened_at, presence: true
  validates :opening_cash_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :device_belongs_to_store
  validate :drawer_belongs_to_store
  validate :business_day_belongs_to_store
  validate :reconciled_markers_immutable

  scope :open_sessions, -> { where(status: "open") }

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end

  def cash_enabled?
    cash_drawer_id.present?
  end

  private

  def device_belongs_to_store
    return if pos_device.blank? || store.blank?
    return if pos_device.store_id == store_id

    errors.add(:pos_device, "must belong to the same store")
  end

  def drawer_belongs_to_store
    return if cash_drawer.blank? || store.blank?
    return if cash_drawer.store_id == store_id

    errors.add(:cash_drawer, "must belong to the same store")
  end

  def business_day_belongs_to_store
    return if business_day.blank? || store.blank?
    return if business_day.store_id == store_id

    errors.add(:business_day, "must belong to the same store")
  end

  def reconciled_markers_immutable
    return unless persisted?
    return if reconciled_at_in_database.blank?
    return unless will_save_change_to_reconciled_at? || will_save_change_to_reconciled_by_user_id?

    errors.add(:base, "reconciliation markers cannot be changed once set")
  end
end
