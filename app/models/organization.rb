# frozen_string_literal: true

class Organization < ApplicationRecord
  include TimezoneValidatable

  has_many :stores, dependent: :restrict_with_exception
  has_many :roles, dependent: :restrict_with_exception
  has_many :administrative_audit_events, dependent: :restrict_with_exception
  has_many :products, dependent: :restrict_with_exception
  has_many :tax_categories, dependent: :restrict_with_exception
  has_many :return_policies, dependent: :restrict_with_exception
  has_many :return_reasons, dependent: :restrict_with_exception
  has_many :discount_reasons, dependent: :restrict_with_exception
  has_many :departments, dependent: :restrict_with_exception
  has_many :merchandise_classes, dependent: :restrict_with_exception
  has_many :product_formats, dependent: :restrict_with_exception
  has_many :product_conditions, dependent: :restrict_with_exception
  has_many :inventory_adjustment_reasons, dependent: :restrict_with_exception
  has_many :tender_types, dependent: :restrict_with_exception
  has_many :cash_movement_types, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :default_currency_code, presence: true, length: { is: 3 }
  validates :default_timezone, presence: true
  validates_timezone :default_timezone
  validates :active, inclusion: { in: [ true, false ] }
  validate :installation_has_at_most_one_organization, on: :create

  private

  # INV-ORG-001 — one operating Organization per installation.
  def installation_has_at_most_one_organization
    return unless Organization.exists?

    errors.add(:base, "installation already has an organization (INV-ORG-001)")
  end
end
