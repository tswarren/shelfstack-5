# frozen_string_literal: true

class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :restrict_with_exception
  has_many :roles, through: :role_permissions

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :active, inclusion: { in: [ true, false ] }

  # Permission codes are code-managed; do not rename after create.
  attr_readonly :code
end
