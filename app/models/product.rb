# frozen_string_literal: true

class Product < ApplicationRecord
  STATUSES = %w[active inactive discontinued].freeze
  VARIANT_STRUCTURES = %w[single].freeze
  IDENTIFIER_VALIDATION_STATUSES = %w[valid warning invalid not_applicable].freeze

  belongs_to :organization
  belongs_to :product_format, optional: true
  belongs_to :merchandise_class, optional: true
  belongs_to :default_department, class_name: "Department", optional: true
  belongs_to :default_tax_category, class_name: "TaxCategory", optional: true
  has_many :product_variants, dependent: :restrict_with_exception

  attr_readonly :identifier

  validates :identifier, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :variant_structure, presence: true, inclusion: { in: VARIANT_STRUCTURES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :identifier_validation_status, presence: true,
            inclusion: { in: IDENTIFIER_VALIDATION_STATUSES }
  validates :sellable, inclusion: { in: [ true, false ] }
  validates :identifier_generated, inclusion: { in: [ true, false ] }
  validates :list_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
end
