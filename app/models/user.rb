# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  has_secure_password :pin, validations: false

  belongs_to :default_store, class_name: "Store", optional: true
  has_many :store_memberships, dependent: :restrict_with_exception
  has_many :stores, through: :store_memberships

  before_validation :normalize_username

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :user_number, uniqueness: true, allow_nil: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :failed_login_attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def locked?
    locked_at.present?
  end

  def can?(permission_key, store:)
    ::Authorization::EvaluatePermission.call(user: self, store: store, permission_key: permission_key) == :allow
  end

  private

  def normalize_username
    self.username = username.to_s.strip.downcase.presence
  end
end
