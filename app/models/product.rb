# frozen_string_literal: true

class Product < ApplicationRecord
  STATUSES = %w[active inactive discontinued].freeze
  VARIANT_STRUCTURES = %w[single].freeze
  IDENTIFIER_VALIDATION_STATUSES = %w[valid warning invalid not_applicable].freeze
  PRODUCT_TYPES = %w[
    book recorded_music video periodical game stationery gift cafe service other
  ].freeze

  belongs_to :organization
  belongs_to :product_format
  belongs_to :merchandise_class, optional: true
  belongs_to :default_department, class_name: "Department", optional: true
  belongs_to :default_tax_category, class_name: "TaxCategory", optional: true
  has_many :product_variants, dependent: :restrict_with_exception
  has_many :product_requests, dependent: :restrict_with_exception
  has_many :product_creators, -> { order(:position, :id) }, dependent: :restrict_with_exception
  has_many :creators, through: :product_creators

  attr_readonly :identifier

  before_validation :normalize_alternate_identifier
  before_validation :normalize_language_code

  validates :identifier, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :product_type, presence: true, inclusion: { in: PRODUCT_TYPES }
  validates :product_format, presence: true
  validates :variant_structure, presence: true, inclusion: { in: VARIANT_STRUCTURES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :identifier_validation_status, presence: true,
            inclusion: { in: IDENTIFIER_VALIDATION_STATUSES }
  validates :sellable, inclusion: { in: [ true, false ] }
  validates :identifier_generated, inclusion: { in: [ true, false ] }
  validates :list_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validate :availability_window_order
  validate :classification_belongs_to_organization
  validate :sellable_requires_standard_variant
  validate :single_structure_has_at_most_one_variant
  validate :publication_date_precision_consistent

  private

  def normalize_alternate_identifier
    return if alternate_identifier.blank?

    self.alternate_identifier = alternate_identifier.to_s.strip.gsub(/[\s\-]/, "")
  end

  # No hard enum -- normalize whitespace/case only (OD-P8-10).
  def normalize_language_code
    return if language_code.blank?

    self.language_code = language_code.to_s.strip.gsub(/\s+/, " ").downcase
  end

  def publication_date_precision_consistent
    result = Catalog::PartialPublicationDate.validate(date: publication_date, precision: publication_date_precision)
    return if result.valid?

    result.errors.each { |message| errors.add(:publication_date, message) }
  end

  def availability_window_order
    return if available_from.blank? || available_until.blank?
    return if available_from <= available_until

    errors.add(:available_until, "must be on or after available_from")
  end

  def classification_belongs_to_organization
    if merchandise_class.present? && merchandise_class.organization_id != organization_id
      errors.add(:merchandise_class, "must belong to the same organization")
    end
    if default_department.present? && default_department.organization_id != organization_id
      errors.add(:default_department, "must belong to the same organization")
    end
    if default_tax_category.present? && default_tax_category.organization_id != organization_id
      errors.add(:default_tax_category, "must belong to the same organization")
    end
    if product_format.present? && product_format.organization_id != organization_id
      errors.add(:product_format, "must belong to the same organization")
    end
  end

  def sellable_requires_standard_variant
    return unless sellable?
    return if product_variants.any?

    errors.add(:sellable, "requires at least one variant")
  end

  def single_structure_has_at_most_one_variant
    return unless variant_structure == "single"
    return if product_variants.size <= 1

    errors.add(:variant_structure, "single allows only one variant")
  end
end
