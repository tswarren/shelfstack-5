# frozen_string_literal: true

class Role < ApplicationRecord
  belongs_to :organization
  has_many :role_permissions, dependent: :restrict_with_exception
  has_many :permissions, through: :role_permissions
  has_many :store_memberships, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :active, inclusion: { in: [ true, false ] }
  validates :system_template, inclusion: { in: [ true, false ] }
end
