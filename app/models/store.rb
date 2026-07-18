# frozen_string_literal: true

class Store < ApplicationRecord
  include TimezoneValidatable

  belongs_to :organization
  has_many :defaulting_users, class_name: "User", foreign_key: :default_store_id, dependent: :nullify, inverse_of: :default_store
  has_many :store_memberships, dependent: :restrict_with_exception
  has_many :users, through: :store_memberships
  has_many :pos_devices, dependent: :restrict_with_exception
  has_many :cash_drawers, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :timezone, presence: true
  validates_timezone :timezone
  validates :currency_code, presence: true, length: { is: 3 }
  validates :active, inclusion: { in: [ true, false ] }
  validates :store_number, uniqueness: { scope: :organization_id }, allow_nil: true
  validates :postal_code, length: { maximum: 12 }, allow_nil: true
  validates :country_code, length: { is: 2 }, allow_nil: true
  validates :phone, length: { maximum: 30 }, allow_nil: true
  validates :san_number, length: { maximum: 8 }, allow_nil: true
end
