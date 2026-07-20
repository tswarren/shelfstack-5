# frozen_string_literal: true

class StoreMembership < ApplicationRecord
  belongs_to :user
  belongs_to :store
  belongs_to :role
  belongs_to :assigned_by_user, class_name: "User", optional: true

  # Identity of a grant is immutable; transfer access by deactivating and creating a new membership.
  attr_readonly :user_id, :store_id

  validates :user_id, uniqueness: { scope: :store_id }
  validates :active, inclusion: { in: [ true, false ] }
  validate :role_belongs_to_store_organization
  validate :date_range_valid
  validate :authority_amounts_non_negative
  validate :authority_rates_in_range
  validate :identity_unchanged, on: :update

  def effective_on?(date = nil)
    date ||= store_local_today
    return false unless active?
    return false if starts_on.present? && date < starts_on
    return false if ends_on.present? && date > ends_on

    true
  end

  def store_local_today
    StoreTime.today(store)
  end

  private

  def identity_unchanged
    errors.add(:user_id, "cannot be changed after creation") if user_id_changed?
    errors.add(:store_id, "cannot be changed after creation") if store_id_changed?
  end

  def role_belongs_to_store_organization
    return if role.blank? || store.blank?
    return if role.organization_id == store.organization_id

    errors.add(:role, "must belong to the same organization as the store")
  end

  def date_range_valid
    return if starts_on.blank? || ends_on.blank?
    return if starts_on <= ends_on

    errors.add(:ends_on, "must be on or after starts_on")
  end

  def authority_amounts_non_negative
    %i[
      maximum_discount_amount_cents
      maximum_cash_refund_cents
      maximum_no_receipt_return_cents
      maximum_paid_out_cents
      cash_variance_review_threshold_cents
    ].each do |attribute|
      value = public_send(attribute)
      next if value.nil? || value >= 0

      errors.add(attribute, "must be greater than or equal to 0")
    end
  end

  def authority_rates_in_range
    %i[maximum_discount_rate maximum_price_override_rate].each do |attribute|
      value = public_send(attribute)
      next if value.nil? || (value >= 0 && value <= 1)

      errors.add(attribute, "must be between 0 and 1")
    end
  end
end
