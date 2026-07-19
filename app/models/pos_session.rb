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
  has_many :pos_transactions, foreign_key: :origin_pos_session_id, inverse_of: :origin_pos_session,
           dependent: :restrict_with_exception
  has_many :active_pos_transactions, class_name: "PosTransaction", foreign_key: :active_pos_session_id,
           inverse_of: :active_pos_session, dependent: :nullify
  has_many :completed_pos_transactions, class_name: "PosTransaction", foreign_key: :completed_pos_session_id,
           inverse_of: :completed_pos_session, dependent: :restrict_with_exception
  has_many :pos_cash_movements, dependent: :restrict_with_exception

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opened_at, presence: true
  validate :device_belongs_to_store
  validate :drawer_belongs_to_store
  validate :business_day_belongs_to_store

  scope :open_sessions, -> { where(status: "open") }

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
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
end
