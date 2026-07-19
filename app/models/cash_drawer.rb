# frozen_string_literal: true

class CashDrawer < ApplicationRecord
  belongs_to :store
  has_many :pos_sessions, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: { scope: :store_id }
  validates :name, presence: true
  validates :active, inclusion: { in: [ true, false ] }
end
