# frozen_string_literal: true

class TenderType < ApplicationRecord
  TENDER_CATEGORIES = %w[cash card check stored_value other].freeze
  REFERENCE_REQUIREMENTS = %w[none optional required].freeze

  belongs_to :organization

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :tender_category, presence: true, inclusion: { in: TENDER_CATEGORIES }
  validates :reference_1_requirement, inclusion: { in: REFERENCE_REQUIREMENTS }
  validates :reference_2_requirement, inclusion: { in: REFERENCE_REQUIREMENTS }
  validates :shortcut, uniqueness: { scope: :organization_id }, allow_nil: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :payment_enabled, :refund_enabled, :allows_over_tender, :provides_change,
            inclusion: { in: [ true, false ] }
end
