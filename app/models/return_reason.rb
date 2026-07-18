# frozen_string_literal: true

class ReturnReason < ApplicationRecord
  belongs_to :organization

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :active, inclusion: { in: [ true, false ] }
end
