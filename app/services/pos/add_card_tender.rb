# frozen_string_literal: true

module Pos
  # Standalone-terminal card Tender (domain "Card"): ShelfStack cannot make the
  # external terminal authorization part of its own database transaction (MVP
  # limitation, ADR-0009), so external approval is confirmed by the cashier before
  # this call and stored as `authorized` with `authorization_code`,
  # `terminal_reference`, and `authorized_at`. If internal completion later fails,
  # this authorized Tender remains visible/unsettled for operational follow-up
  # rather than being reverted.
  class AddCardTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error)

    def initialize(pos_transaction:, tender_type:, amount_cents:, authorization_code:, actor:,
                    terminal_reference: nil, requires_reconciliation: false)
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @authorization_code = authorization_code
      @terminal_reference = terminal_reference
      @requires_reconciliation = requires_reconciliation
      @actor = actor
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "amount must be positive" unless @amount_cents.positive?
      raise Error, "authorization code is required" if @authorization_code.blank?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "received", status: "authorized", amount_cents: @amount_cents,
          authorization_code: @authorization_code, terminal_reference: @terminal_reference,
          authorized_at: Time.current, requires_reconciliation: @requires_reconciliation,
          created_by_user: @actor
        )

        Result.new(pos_tender: tender, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message)
    end
  end
end
