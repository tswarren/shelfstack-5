# frozen_string_literal: true

class Store < ApplicationRecord
  include TimezoneValidatable

  CARD_RECONCILIATION_GRAINS = %w[business_day session].freeze

  belongs_to :organization
  has_many :defaulting_users, class_name: "User", foreign_key: :default_store_id, dependent: :nullify, inverse_of: :default_store
  has_many :store_memberships, dependent: :restrict_with_exception
  has_many :users, through: :store_memberships
  has_many :pos_devices, dependent: :restrict_with_exception
  has_many :cash_drawers, dependent: :restrict_with_exception
  has_many :stock_balances, dependent: :restrict_with_exception
  has_many :inventory_ledger_entries, dependent: :restrict_with_exception
  has_many :inventory_reservations, dependent: :restrict_with_exception
  has_many :inventory_units, dependent: :restrict_with_exception
  has_many :inventory_adjustments, dependent: :restrict_with_exception
  has_many :business_days, dependent: :restrict_with_exception
  has_many :pos_sessions, dependent: :restrict_with_exception
  has_many :pos_transactions, dependent: :restrict_with_exception
  has_many :pos_tenders, dependent: :restrict_with_exception
  has_many :pos_cash_movements, dependent: :restrict_with_exception
  has_many :store_tax_rates, dependent: :restrict_with_exception
  has_many :store_tax_rules, dependent: :restrict_with_exception
  has_many :purchase_orders, dependent: :restrict_with_exception
  has_many :receipts, dependent: :restrict_with_exception
  has_many :product_requests, dependent: :restrict_with_exception
  has_many :stored_value_entries, dependent: :restrict_with_exception
  has_many :pos_session_z_reports, dependent: :restrict_with_exception
  has_many :business_day_z_reports, dependent: :restrict_with_exception
  has_many :pos_close_card_evidences, dependent: :restrict_with_exception
  has_many :reconciliations, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :timezone, presence: true
  validates_timezone :timezone
  validates :currency_code, presence: true, length: { is: 3 }
  validates :active, inclusion: { in: [ true, false ] }
  validates :store_number, uniqueness: { scope: :organization_id }, allow_nil: true
  validates :postal_code, length: { maximum: 12 }, allow_nil: true
  validates :country_code, length: { is: 2 }, allow_nil: true
  validates :phone, length: { maximum: 30 }, allow_nil: true
  validates :san_number, length: { maximum: 8 }, allow_nil: true
  validates :next_receipt_sequence, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :next_purchase_order_number, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :next_receipt_number, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :card_reconciliation_grain, presence: true, inclusion: { in: CARD_RECONCILIATION_GRAINS }
  validates :next_session_z_number, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :next_business_day_z_number, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :session_card_grain_not_yet_operable,
           if: -> { card_reconciliation_grain == "session" && will_save_change_to_card_reconciliation_grain? }

  private

  def session_card_grain_not_yet_operable
    errors.add(
      :card_reconciliation_grain,
      "session grain is not available until merchant-slip session close is implemented"
    )
  end
end
