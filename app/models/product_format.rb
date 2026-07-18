# frozen_string_literal: true

class ProductFormat < ApplicationRecord
  TRACKING_MODES = ProductVariant::INVENTORY_TRACKING_MODES

  belongs_to :organization

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :short_code, presence: true, length: { maximum: 2 }, uniqueness: { scope: :organization_id }
  validates :format_family, presence: true
  validates :default_inventory_tracking_mode, presence: true, inclusion: { in: TRACKING_MODES }
  validates :active, inclusion: { in: [ true, false ] }
end
