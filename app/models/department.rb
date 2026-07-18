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
  has_many :pos_line_items, dependent: :restrict_with_exception

  attr_readonly :code, :department_number

  validates :department_number, presence: true, uniqueness: { scope: :organization_id }
  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :postable, inclusion: { in: [ true, false ] }
  validates :active, inclusion: { in: [ true, false ] }
  validates :default_cost_estimation_margin_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validate :default_tax_category_belongs_to_organization
  validate :postable_when_referenced_as_merchandise_class_default

  private

  def default_tax_category_belongs_to_organization
    return if default_tax_category.blank?

    if default_tax_category.organization_id != organization_id
      errors.add(:default_tax_category, "must belong to the same organization")
    end
  end

  def postable_when_referenced_as_merchandise_class_default
    return if postable?
    return if id.blank?

    referenced = MerchandiseClass.where(organization_id: organization_id, active: true).where(
      "default_department_id = :id OR default_used_department_id = :id",
      id: id
    ).exists?

    return unless referenced

    errors.add(
      :postable,
      "cannot be false while active merchandise classes use this department as a default"
    )
  end
end
