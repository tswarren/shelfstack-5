# frozen_string_literal: true

class PosTransaction < ApplicationRecord
  STATUSES = %w[open suspended completed cancelled].freeze

  belongs_to :store
  belongs_to :origin_pos_session, class_name: "PosSession", inverse_of: :pos_transactions
  belongs_to :active_pos_session, class_name: "PosSession", optional: true, inverse_of: :active_pos_transactions
  belongs_to :cashier_user, class_name: "User"
  belongs_to :cancelled_by_user, class_name: "User", optional: true
  has_many :pos_line_items, dependent: :restrict_with_exception

  before_validation :assign_public_id, on: :create

  validates :public_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opened_at, presence: true

  scope :open_transactions, -> { where(status: "open") }
  scope :suspended, -> { where(status: "suspended") }

  def open?
    status == "open"
  end

  def suspended?
    status == "suspended"
  end

  def completed?
    status == "completed"
  end

  def cancelled?
    status == "cancelled"
  end

  def editable?
    open?
  end

  private

  def assign_public_id
    self.public_id ||= SecureRandom.uuid
  end
end
