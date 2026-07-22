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
  validate :alternate_identifier_not_canonical_collision
  validate :account_number_not_alternate_collision

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
    self.alternate_identifier = self.class.normalize_alternate_identifier(alternate_identifier)
  end

  def self.normalize_alternate_identifier(raw)
    return nil if raw.blank?

    raw.to_s.strip.gsub(/[\s\-]/, "").downcase.presence
  end

  # True when any account in the organization already uses this value as a
  # canonical account number or alternate identifier (optionally excluding one id).
  def self.credential_occupied?(organization_id:, value:, excluding_id: nil)
    normalized = normalize_alternate_identifier(value) || value.to_s
    return false if normalized.blank?

    scope = where(organization_id: organization_id)
      .where("account_number = :value OR alternate_identifier = :value", value: normalized)
    scope = scope.where.not(id: excluding_id) if excluding_id
    scope.exists?
  end

  def account_number_is_generated_21
    return if account_number.blank?

    normalized = Identifiers::Normalize.call(account_number)
    return if normalized.type == :generated_21 && normalized.validation_status == :valid

    errors.add(:account_number, "must be a valid generated namespace 21 EAN-13")
  end

  def alternate_identifier_not_canonical_collision
    return if alternate_identifier.blank?

    collision = organization.stored_value_accounts
      .where(account_number: alternate_identifier)
      .where.not(id: id)
      .exists?
    errors.add(:alternate_identifier, "matches an existing account number") if collision
  end

  def account_number_not_alternate_collision
    return if account_number.blank?

    collision = organization.stored_value_accounts
      .where(alternate_identifier: account_number)
      .where.not(id: id)
      .exists?
    errors.add(:account_number, "matches an existing alternate identifier") if collision
  end
end
