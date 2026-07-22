# frozen_string_literal: true

module Pos
  # Standalone-terminal card Tender (domain "Card"): ShelfStack cannot make the
  # external terminal authorization part of its own database transaction (MVP
  # limitation, ADR-0009), so external approval is confirmed by the cashier before
  # this call and stored as `authorized` with `authorization_code`,
  # `terminal_reference`, and `authorized_at`. If internal completion later fails,
  # this authorized Tender remains visible/unsettled for operational follow-up
  # rather than being reverted.
  #
  # Amounts that exceed remaining balance when the Tender Type disallows over-tender
  # are rejected unless an authorization already exists — then the tender is retained
  # with `requires_reconciliation: true` (external fact must not be discarded).
  class AddCardTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error, :warnings)

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
      TenderGuards.assert_active!(@tender_type)
      TenderGuards.assert_payment_enabled!(@tender_type)

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?
        TenderGuards.assert_no_outstanding_card_refund_preparation!(transaction)

        recalculation = recalculate_for_tender!(transaction)
        TenderGuards.assert_no_calculation_blockers!(recalculation)

        balance_due = TenderGuards.remaining_received_balance_cents(transaction, recalculation.net_total_cents)
        raise Error, "no balance due" if balance_due.zero?

        requires_reconciliation = @requires_reconciliation
        if !@tender_type.allows_over_tender? && @amount_cents > balance_due
          # Authorization already exists externally — retain with recon rather than discard.
          requires_reconciliation = true
        end

        tender = PosTender.create!(
          pos_transaction: transaction, store: transaction.store, tender_type: @tender_type,
          direction: "received", status: "authorized", amount_cents: @amount_cents,
          authorization_code: @authorization_code, terminal_reference: @terminal_reference,
          authorized_at: Time.current, requires_reconciliation: requires_reconciliation,
          created_by_user: @actor
        )

        Result.new(pos_tender: tender, success?: true, error: nil, warnings: recalculation.warnings)
      end
    rescue Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def recalculate_for_tender!(transaction)
      if transaction.pos_line_items.pending.returns.where.not(original_pos_line_item_id: nil).exists?
        FinalizeReturnFinancials.call(pos_transaction: transaction).recalculation
      else
        RecalculateTransaction.call(pos_transaction: transaction)
      end
    end
  end
end
