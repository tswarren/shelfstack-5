# frozen_string_literal: true

# Gift Card, Store Credit, or Trade Credit account (ADR-0012). Canonical
# identity is a generated organization-wide `21` EAN-13 `account_number`;
# `current_balance_cents` is a required operational cache that reconciles to
# the append-only StoredValueEntry ledger, which remains authoritative.
# `lock_version` is a defense-in-depth optimistic guard alongside the
# pessimistic row lock StoredValue::PostEntry takes before posting.
class StoredValueAccount < ApplicationRecord
  ACCOUNT_TYPES = %w[gift_card store_credit trade_credit].freeze
  STATUSES = %w[active suspended].freeze

  belongs_to :organization
  belongs_to :created_by_user, class_name: "User"
  has_many :stored_value_entries, dependent: :restrict_with_exception

  attr_readonly :account_type, :account_number

  before_validation :normalize_alternate_identifier

  validates :account_type, presence: true, inclusion: { in: ACCOUNT_TYPES }
  validates :account_number, presence: true, uniqueness: true
  validates :alternate_identifier, uniqueness: { scope: :organization_id }, allow_nil: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :current_balance_cents, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :account_number_is_generated_21

  scope :active, -> { where(status: "active") }
  scope :suspended, -> { where(status: "suspended") }

  def active?
    status == "active"
  end

  def suspended?
    status == "suspended"
  end

  # `depleted` is derived from balance, never persisted (v1 policy).
  def depleted?
    current_balance_cents.zero?
  end

  private

  def normalize_alternate_identifier
    return if alternate_identifier.blank?

    self.alternate_identifier = alternate_identifier.to_s.strip.gsub(/[\s\-]/, "")
  end

  def account_number_is_generated_21
    return if account_number.blank?

    normalized = Identifiers::Normalize.call(account_number)
    return if normalized.type == :generated_21 && normalized.validation_status == :valid

    errors.add(:account_number, "must be a valid generated namespace 21 EAN-13")
  end
end
