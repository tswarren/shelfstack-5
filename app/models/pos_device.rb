# frozen_string_literal: true

class PosDevice < ApplicationRecord
  DEVICE_TYPES = %w[register mobile_pos back_office self_checkout].freeze

  belongs_to :store

  validates :code, presence: true, uniqueness: { scope: :store_id }
  validates :name, presence: true
  validates :device_type, presence: true, inclusion: { in: DEVICE_TYPES }
  validates :active, inclusion: { in: [ true, false ] }
end
