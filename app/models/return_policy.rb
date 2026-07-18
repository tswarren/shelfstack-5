# frozen_string_literal: true

class ReturnPolicy < ApplicationRecord
  belongs_to :organization
  has_many :departments, foreign_key: :default_return_policy_id, dependent: :restrict_with_exception,
                         inverse_of: :default_return_policy
  has_many :discount_reasons, foreign_key: :resulting_return_policy_id, dependent: :restrict_with_exception,
                              inverse_of: :resulting_return_policy

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :final_sale, inclusion: { in: [ true, false ] }
  validates :active, inclusion: { in: [ true, false ] }
  validates :return_window_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
end
