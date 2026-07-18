# frozen_string_literal: true

class MerchandiseClass < ApplicationRecord
  include Hierarchical

  LEVELS = %w[primary secondary minor].freeze

  belongs_to :organization
  belongs_to :parent, class_name: "MerchandiseClass", optional: true
  belongs_to :default_department, class_name: "Department", optional: true
  belongs_to :default_used_department, class_name: "Department", optional: true
  belongs_to :default_tax_category, class_name: "TaxCategory", optional: true
  has_many :children, class_name: "MerchandiseClass", foreign_key: :parent_id,
           inverse_of: :parent, dependent: :restrict_with_exception

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :level, presence: true, inclusion: { in: LEVELS }
  validates :active, inclusion: { in: [ true, false ] }
  validate :parent_required_for_non_primary_levels
  validate :parent_level_matches_child_level
  validate :default_departments_are_postable

  private

  def parent_required_for_non_primary_levels
    return if level == "primary" || parent.present?

    errors.add(:parent, "is required for #{level} level")
  end

  def parent_level_matches_child_level
    return if parent.blank?

    expected_parent_level = case level
    when "secondary" then "primary"
    when "minor" then "secondary"
    else
      errors.add(:parent, "must not be present for primary level") if level == "primary"
      return
    end

    return if parent.level == expected_parent_level

    errors.add(:parent, "must be #{expected_parent_level} level")
  end

  def default_departments_are_postable
    if default_department.present? && !default_department.postable?
      errors.add(:default_department, "must be postable")
    end
    if default_used_department.present? && !default_used_department.postable?
      errors.add(:default_used_department, "must be postable")
    end
  end
end
