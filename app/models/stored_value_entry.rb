# frozen_string_literal: true

# Append-only Stored-Value ledger entry (ADR-0012). The Ledger is
# authoritative; StoredValue::PostEntry is the exclusive writer and owns the
# matching StoredValueAccount#current_balance_cents cache update.
class StoredValueEntry < ApplicationRecord
  ENTRY_TYPES = %w[issued reloaded redeemed refunded manual_adjustment reversal].freeze
  # Issuance, reload, and refund are positive; redemption is negative
  # (stored-value v1 operating policy). `manual_adjustment` and `reversal`
  # may take either sign and are not constrained here.
  POSITIVE_ENTRY_TYPES = %w[issued reloaded refunded].freeze
  NEGATIVE_ENTRY_TYPES = %w[redeemed].freeze

  belongs_to :stored_value_account
  belongs_to :store
  belongs_to :pos_transaction, optional: true
  belongs_to :pos_line_item, optional: true
  belongs_to :pos_tender, optional: true
  belongs_to :reverses_entry, class_name: "StoredValueEntry", optional: true
  belongs_to :stored_value_adjustment_reason, optional: true
  belongs_to :created_by_user, class_name: "User"
  belongs_to :pos_approval, optional: true
  has_one :reversal_entry, class_name: "StoredValueEntry", foreign_key: :reverses_entry_id,
          inverse_of: :reverses_entry, dependent: :restrict_with_exception

  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }
  validates :amount_cents, presence: true, numericality: { only_integer: true, other_than: 0 }
  validates :posting_key, presence: true, uniqueness: true
  validate :account_and_store_same_organization
  validate :sign_matches_entry_type
  validate :reversal_requires_reference
  validate :manual_adjustment_requires_reason_and_approval

  before_destroy :prevent_mutation
  before_update :prevent_mutation

  scope :for_account, ->(account) { where(stored_value_account: account) }

  def readonly?
    !new_record?
  end

  def credit?
    amount_cents.positive?
  end

  def debit?
    amount_cents.negative?
  end

  private

  def account_and_store_same_organization
    return if stored_value_account.blank? || store.blank?
    return if stored_value_account.organization_id == store.organization_id

    errors.add(:base, "account and store must belong to the same organization")
  end

  def sign_matches_entry_type
    return if amount_cents.blank?

    if POSITIVE_ENTRY_TYPES.include?(entry_type) && !amount_cents.positive?
      errors.add(:amount_cents, "must be positive for #{entry_type} entries")
    elsif NEGATIVE_ENTRY_TYPES.include?(entry_type) && !amount_cents.negative?
      errors.add(:amount_cents, "must be negative for #{entry_type} entries")
    end
  end

  # Mirrors the intended `reverses_entry_id` linkage contract at the model
  # layer (the migration itself does not add a DB check constraint for this).
  def reversal_requires_reference
    if entry_type == "reversal"
      errors.add(:reverses_entry, "is required for reversal entries") if reverses_entry_id.blank?
    elsif reverses_entry_id.present?
      errors.add(:reverses_entry, "may only be set on reversal entries")
    end
  end

  # Every manual adjustment requires an active reason and an independent
  # PosApproval — stored-value v1 policy "no monetary threshold" approval rule.
  def manual_adjustment_requires_reason_and_approval
    if entry_type == "manual_adjustment"
      if stored_value_adjustment_reason_id.blank?
        errors.add(:stored_value_adjustment_reason, "is required for manual adjustments")
      end
      errors.add(:pos_approval, "is required for manual adjustments") if pos_approval_id.blank?
      if stored_value_adjustment_reason&.requires_note? && description.blank?
        errors.add(:description, "is required for this adjustment reason")
      end
    elsif stored_value_adjustment_reason_id.present?
      errors.add(:stored_value_adjustment_reason, "may only be set on manual adjustment entries")
    end
  end

  def prevent_mutation
    errors.add(:base, "stored value entries are append-only")
    throw(:abort)
  end
end
