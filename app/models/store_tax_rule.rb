# frozen_string_literal: true

# Connects a Store, Tax Category, and (when applicable) a Store Tax Rate under an explicit
# `treatment`. Tax Category never carries a global taxable/zero-rated/exempt status (ADR-0014);
# actual treatment always depends on the Store Tax Rule.
#
# Treatments:
# - taxable — statutory rate applies; collect tax
# - zero_rated — within the tax system at an explicit 0% rate (VAT/GST-style; uncommon in US demo)
# - exempt — tax would ordinarily be relevant but statute/customer excludes the sale
# - not_applicable — component is outside the scope of this merchandise (e.g. food tax on books)
class StoreTaxRule < ApplicationRecord
  TREATMENTS = %w[taxable zero_rated exempt not_applicable].freeze
  RATE_REQUIRED_TREATMENTS = %w[taxable zero_rated].freeze
  NON_COLLECTING_TREATMENTS = %w[exempt not_applicable].freeze

  belongs_to :store
  belongs_to :tax_category
  belongs_to :store_tax_rate, optional: true

  validates :treatment, presence: true, inclusion: { in: TREATMENTS }
  validates :component_code, presence: true
  validates :taxable_fraction, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :calculation_order, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :compounds_on_prior_tax, inclusion: { in: [ true, false ] }
  validates :active, inclusion: { in: [ true, false ] }
  validate :effective_period_order
  validate :store_tax_rate_presence_matches_treatment
  validate :store_tax_rate_value_matches_treatment
  validate :store_tax_rate_identity_consistent
  validate :tax_category_belongs_to_store_organization
  validate :effective_period_does_not_overlap
  validate :calculation_order_and_compounding_consistent_within_rate

  private

  def effective_period_order
    return if effective_from.blank? || effective_to.blank?
    return if effective_from <= effective_to

    errors.add(:effective_to, "must be on or after effective_from")
  end

  def store_tax_rate_presence_matches_treatment
    return unless RATE_REQUIRED_TREATMENTS.include?(treatment)
    return if store_tax_rate_id.present?

    errors.add(:store_tax_rate, "is required for #{treatment} treatment")
  end

  def store_tax_rate_value_matches_treatment
    return if store_tax_rate.blank?

    case treatment
    when "taxable"
      if store_tax_rate.rate.present? && store_tax_rate.rate.negative?
        errors.add(:store_tax_rate, "must have a nonnegative rate for taxable treatment")
      end
    when "zero_rated"
      errors.add(:store_tax_rate, "must reference an explicit 0% rate for zero_rated treatment") unless store_tax_rate.zero_rate?
    end
  end

  def store_tax_rate_identity_consistent
    return if store_tax_rate.blank?

    if component_code.present? && component_code != store_tax_rate.code
      errors.add(:component_code, "must equal the referenced store tax rate's code")
    end

    if store_id.present? && store_tax_rate.store_id.present? && store_id != store_tax_rate.store_id
      errors.add(:store_tax_rate, "must belong to the same store as this rule")
    end
  end

  def tax_category_belongs_to_store_organization
    return if tax_category.blank? || store.blank?
    return if tax_category.organization_id == store.organization_id

    errors.add(:tax_category, "must belong to the same organization as the store")
  end

  # Effective periods must not overlap for the same (store_id, tax_category_id, component_code).
  # Nil effective_from/effective_to represent an open-ended boundary.
  def effective_period_does_not_overlap
    return if store_id.blank? || tax_category_id.blank? || component_code.blank?
    return unless active?

    siblings = StoreTaxRule.where(store_id: store_id, tax_category_id: tax_category_id,
                                   component_code: component_code, active: true)
    siblings = siblings.where.not(id: id) if persisted?

    overlapping = siblings.any? { |other| periods_overlap?(other) }
    return unless overlapping

    errors.add(:base,
      "effective period overlaps another active store tax rule for the same store, tax category, and component code")
  end

  def periods_overlap?(other)
    (other.effective_from.nil? || effective_to.nil? || other.effective_from <= effective_to) &&
      (effective_from.nil? || other.effective_to.nil? || effective_from <= other.effective_to)
  end

  # ADR-0014: rules sharing a store_tax_rate_id must use a consistent calculation_order and
  # compounding behavior so the transaction-component identity stays unambiguous.
  def calculation_order_and_compounding_consistent_within_rate
    return if store_tax_rate_id.blank?

    siblings = StoreTaxRule.where(store_tax_rate_id: store_tax_rate_id, active: true)
    siblings = siblings.where.not(id: id) if persisted?

    inconsistent = siblings.where.not(calculation_order: calculation_order)
                           .or(siblings.where.not(compounds_on_prior_tax: compounds_on_prior_tax))
    return unless inconsistent.exists?

    errors.add(:base,
      "calculation_order and compounds_on_prior_tax must be consistent for all rules sharing the same store tax rate")
  end
end
