# frozen_string_literal: true

# Durable external card confirmation for post-void. Operators prepare, run the
# terminal, then record authorization before PostVoidTransaction consumes the
# preparation. A recorded-but-unconsumed prep survives post-void failure.
class PosPostVoidCardPreparation < ApplicationRecord
  STATUSES = %w[prepared recorded consumed abandoned].freeze
  TTL = 30.minutes

  belongs_to :original_pos_transaction, class_name: "PosTransaction"
  belongs_to :original_pos_tender, class_name: "PosTender"
  belongs_to :store
  belongs_to :prepared_by_user, class_name: "User"
  belongs_to :recorded_by_user, class_name: "User", optional: true
  belongs_to :abandoned_by_user, class_name: "User", optional: true
  belongs_to :consumed_by_user, class_name: "User", optional: true
  belongs_to :correcting_pos_transaction, class_name: "PosTransaction", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :expires_at, presence: true

  scope :prepared, -> { where(status: "prepared") }
  scope :recorded_unresolved, -> { where(status: "recorded", consumed_at: nil) }
  scope :active, -> { where(status: %w[prepared recorded]) }

  def prepared?
    status == "prepared"
  end

  def recorded?
    status == "recorded"
  end

  def consumed?
    status == "consumed"
  end

  def abandoned?
    status == "abandoned"
  end

  def unresolved_recorded?
    recorded? && consumed_at.nil?
  end
end
