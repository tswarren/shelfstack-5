# frozen_string_literal: true

class PosTransaction < ApplicationRecord
  STATUSES = %w[open suspended completed cancelled].freeze

  belongs_to :store
  belongs_to :origin_pos_session, class_name: "PosSession", inverse_of: :pos_transactions
  belongs_to :active_pos_session, class_name: "PosSession", optional: true, inverse_of: :active_pos_transactions
  belongs_to :completed_pos_session, class_name: "PosSession", optional: true
  belongs_to :cashier_user, class_name: "User"
  belongs_to :cancelled_by_user, class_name: "User", optional: true
  belongs_to :completed_by_user, class_name: "User", optional: true
  has_many :pos_line_items, dependent: :restrict_with_exception
  has_many :pos_discounts, dependent: :restrict_with_exception
  has_many :pos_tax_exemptions, dependent: :restrict_with_exception
  has_many :pos_approvals, dependent: :restrict_with_exception
  has_many :pos_tenders, dependent: :restrict_with_exception

  before_validation :assign_public_id, on: :create

  validates :public_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opened_at, presence: true
  validates :completion_idempotency_key, uniqueness: true, allow_nil: true
  validates :receipt_number, uniqueness: { scope: :store_id }, allow_nil: true

  scope :open_transactions, -> { where(status: "open") }
  scope :suspended, -> { where(status: "suspended") }
  scope :completed, -> { where(status: "completed") }

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

  # Commercial editing (lines, prices, discounts, tax category, exemptions) is
  # locked while a pending or authorized Tender exists (domain "Tender-state lock").
  # Clearing (removing/voiding) the Tender restores editability.
  def editable?
    open? && !unresolved_tenders?
  end

  def unresolved_tenders?
    pos_tenders.where(status: %w[pending authorized]).exists?
  end

  def tax_exempt?
    pos_tax_exemptions.exists?
  end

  private

  def assign_public_id
    self.public_id ||= SecureRandom.uuid
  end
end
