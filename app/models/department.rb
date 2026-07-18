# frozen_string_literal: true

class Department < ApplicationRecord
  include Hierarchical

  hierarchy_parent_association :parent_department

  belongs_to :organization
  belongs_to :parent_department, class_name: "Department", optional: true
  belongs_to :default_tax_category, class_name: "TaxCategory", optional: true
  belongs_to :default_return_policy, class_name: "ReturnPolicy", optional: true
  has_many :child_departments, class_name: "Department", foreign_key: :parent_department_id,
           inverse_of: :parent_department, dependent: :restrict_with_exception

  attr_readonly :code, :department_number

  validates :department_number, presence: true, uniqueness: { scope: :organization_id }
  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :postable, inclusion: { in: [ true, false ] }
  validates :active, inclusion: { in: [ true, false ] }
  validate :default_tax_category_belongs_to_organization

  private

  def default_tax_category_belongs_to_organization
    return if default_tax_category.blank?

    if default_tax_category.organization_id != organization_id
      errors.add(:default_tax_category, "must belong to the same organization")
    end
  end
end
