# frozen_string_literal: true

class TaxCategory < ApplicationRecord
  belongs_to :organization
  has_many :departments, foreign_key: :default_tax_category_id, dependent: :restrict_with_exception,
                         inverse_of: :default_tax_category
  has_many :merchandise_classes, foreign_key: :default_tax_category_id, dependent: :restrict_with_exception,
                                 inverse_of: :default_tax_category
  has_many :pos_line_items, dependent: :restrict_with_exception

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :active, inclusion: { in: [ true, false ] }
end
