# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :stores, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :default_currency_code, presence: true, length: { is: 3 }
  validates :default_timezone, presence: true
  validates :active, inclusion: { in: [ true, false ] }
end
