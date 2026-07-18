# frozen_string_literal: true

class StoreTaxRate < ApplicationRecord
  belongs_to :store
  has_many :store_tax_rules, dependent: :restrict_with_exception

  attr_readonly :code

  validates :code, presence: true, uniqueness: { scope: :store_id }
  validates :name, presence: true
  validates :rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :receipt_code, length: { maximum: 3 }, allow_nil: true
  validates :active, inclusion: { in: [ true, false ] }
  validate :effective_period_order

  def zero_rate?
    rate.present? && rate.zero?
  end

  private

  def effective_period_order
    return if effective_from.blank? || effective_to.blank?
    return if effective_from <= effective_to

    errors.add(:effective_to, "must be on or after effective_from")
  end
end
