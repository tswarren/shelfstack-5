# frozen_string_literal: true

module StoredValue
  # Read-only facts for a browser Activity Slip (one completed ledger entry).
  class ActivitySlipFacts
    Error = Class.new(StandardError)

    IN_SCOPE_ENTRY_TYPES = %w[issued reloaded refunded].freeze

    TITLES = {
      "issued" => "GIFT CARD ISSUED",
      "reloaded" => "GIFT CARD RELOAD",
      "refunded" => "STORE CREDIT REFUND"
    }.freeze

    AMOUNT_LABELS = {
      "issued" => "Issuance amount",
      "reloaded" => "Reload amount",
      "refunded" => "Refund amount"
    }.freeze

    BALANCE_LABELS = {
      "issued" => "Balance after issuance",
      "reloaded" => "Balance after reload",
      "refunded" => "Balance after refund"
    }.freeze

    ACCOUNT_TYPE_LABELS = {
      "gift_card" => "Gift Card",
      "store_credit" => "Store Credit",
      "trade_credit" => "Trade Credit"
    }.freeze

    Result = Data.define(
      :entry,
      :account,
      :store,
      :title,
      :account_type_label,
      :masked_account_number,
      :amount_label,
      :amount_cents,
      :balance_label,
      :balance_after_cents,
      :receipt_number,
      :entry_at,
      :reprint,
      :reprint_at,
      :footer_text
    )

    def self.call(entry:, store:, reprint: false, reprint_at: nil)
      new(entry:, store:, reprint:, reprint_at:).call
    end

    def initialize(entry:, store:, reprint: false, reprint_at: nil)
      @entry = entry
      @store = store
      @reprint = reprint
      @reprint_at = reprint_at
    end

    def call
      unless IN_SCOPE_ENTRY_TYPES.include?(@entry.entry_type.to_s)
        raise Error, "activity slip is not available for #{@entry.entry_type} entries"
      end

      account = @entry.stored_value_account
      balance = BalanceAfterEntry.call(entry: @entry).balance_cents
      receipt_number = @entry.pos_transaction&.receipt_number

      Result.new(
        entry: @entry,
        account: account,
        store: @store,
        title: TITLES.fetch(@entry.entry_type),
        account_type_label: ACCOUNT_TYPE_LABELS.fetch(account.account_type, account.account_type.to_s.humanize),
        masked_account_number: mask_account_number(account.account_number),
        amount_label: AMOUNT_LABELS.fetch(@entry.entry_type),
        amount_cents: @entry.amount_cents.to_i.abs,
        balance_label: BALANCE_LABELS.fetch(@entry.entry_type),
        balance_after_cents: balance,
        receipt_number: receipt_number,
        entry_at: @entry.created_at,
        reprint: @reprint,
        reprint_at: @reprint ? (@reprint_at || Time.current) : nil,
        footer_text: "This slip records completed activity.\nThe Stored-Value Ledger is authoritative."
      )
    end

    private

    def mask_account_number(number)
      text = number.to_s
      return "****" if text.length < 4

      "**** #{text[-4, 4]}"
    end
  end
end
