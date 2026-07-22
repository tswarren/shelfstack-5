# frozen_string_literal: true

# Durable approved post-void plan bound before terminal card confirmation.
# PostVoidTransaction consumes this preparation (and its approval) rather than
# authorizing after the external card operation.
class PosPostVoidPreparation < ApplicationRecord
  STATUSES = %w[approved consumed abandoned].freeze
  FINGERPRINT_VERSION = 1

  belongs_to :original_pos_transaction, class_name: "PosTransaction"
  belongs_to :store
  belongs_to :prepared_by_user, class_name: "User"
  belongs_to :pos_approval
  belongs_to :abandoned_by_user, class_name: "User", optional: true
  belongs_to :consumed_by_user, class_name: "User", optional: true
  has_many :pos_post_void_card_preparations, dependent: :restrict_with_exception

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reason, presence: true
  validates :commercial_fingerprint, presence: true

  scope :approved, -> { where(status: "approved") }
  scope :active, -> { where(status: "approved") }

  def approved?
    status == "approved"
  end

  def consumed?
    status == "consumed"
  end

  def abandoned?
    status == "abandoned"
  end
end
