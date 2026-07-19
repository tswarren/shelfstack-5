# frozen_string_literal: true

class CashMovementType < ApplicationRecord
  DIRECTIONS = %w[cash_in cash_out].freeze

  belongs_to :organization
  has_many :pos_cash_movements, dependent: :restrict_with_exception

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :active, :requires_approval, :requires_reference, inclusion: { in: [ true, false ] }
end
