# frozen_string_literal: true

class Vendor < ApplicationRecord
  belongs_to :organization
  has_many :product_variant_vendors, dependent: :restrict_with_exception
  has_many :product_variants, through: :product_variant_vendors

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :default_supplier_discount_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validates :ordering_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
