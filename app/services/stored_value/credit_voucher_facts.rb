# frozen_string_literal: true

module StoredValue
  # Read-only facts for a browser Credit Voucher (one active account).
  class CreditVoucherFacts
    Error = Class.new(StandardError)
    SuspendedError = Class.new(Error)

    ACCOUNT_TYPE_LABELS = {
      "gift_card" => "Gift Card",
      "store_credit" => "Store Credit",
      "trade_credit" => "Trade Credit"
    }.freeze

    Result = Data.define(
      :account,
      :store,
      :account_type_label,
      :account_number,
      :current_balance_cents,
      :balance_as_of,
      :barcode,
      :reprint,
      :reprint_at,
      :bearer_warning,
      :redemption_notice
    )

    def self.call(account:, store:, reprint: false, reprint_at: nil, balance_as_of: nil)
      new(account:, store:, reprint:, reprint_at:, balance_as_of:).call
    end

    def initialize(account:, store:, reprint: false, reprint_at: nil, balance_as_of: nil)
      @account = account
      @store = store
      @reprint = reprint
      @reprint_at = reprint_at
      @balance_as_of = balance_as_of
    end

    def call
      raise SuspendedError, "This Stored-Value Account is suspended and cannot be printed as a redeemable Credit Voucher." if @account.suspended?

      as_of = @balance_as_of || Time.current
      Result.new(
        account: @account,
        store: @store,
        account_type_label: ACCOUNT_TYPE_LABELS.fetch(@account.account_type, @account.account_type.to_s.humanize),
        account_number: @account.account_number,
        current_balance_cents: @account.current_balance_cents.to_i,
        balance_as_of: as_of,
        barcode: AccountBarcode.call(account_number: @account.account_number),
        reprint: @reprint,
        reprint_at: @reprint ? (@reprint_at || as_of) : nil,
        bearer_warning: "Treat this voucher like cash.\nPossession may permit use of the associated\nStored-Value Account.",
        redemption_notice: "The current ShelfStack balance and Account\nstatus control redemption."
      )
    end
  end
end
