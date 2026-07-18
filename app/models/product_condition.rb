# frozen_string_literal: true

class ProductCondition < ApplicationRecord
  belongs_to :organization

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
end
