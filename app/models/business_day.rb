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

  scope :open_days, -> { where(status: "open") }

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end
end
