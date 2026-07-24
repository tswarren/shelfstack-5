# frozen_string_literal: true

# Ordered Product-Creator join (OD-P8-02). Positions are service-authoritative
# (see Catalog::ReplaceProductCreators) -- this model does not derive them.
# Same Creator + role on one Product uses soft validation only; there is no
# unique database constraint on (product_id, creator_id, role).
class ProductCreator < ApplicationRecord
  ROLES = %w[author editor illustrator translator narrator photographer contributor].freeze

  belongs_to :product
  belongs_to :creator

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :credited_as, length: { maximum: 255 }, allow_blank: true
  validate :creator_belongs_to_product_organization
  validate :soft_unique_creator_role_per_product

  private

  def creator_belongs_to_product_organization
    return if product.blank? || creator.blank?

    if product.organization_id != creator.organization_id
      errors.add(:creator, "must belong to the same organization as the product")
    end
  end

  def soft_unique_creator_role_per_product
    return if product_id.blank? || creator_id.blank? || role.blank?

    scope = ProductCreator.where(product_id: product_id, creator_id: creator_id, role: role)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:creator_id, "is already linked to this product with the same role") if scope.exists?
  end
end
