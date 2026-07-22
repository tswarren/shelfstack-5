# frozen_string_literal: true

module Pos
  # Creates an already-voided card tender when an external authorization was
  # entered but could not be attached (amount mismatch). Requires explicit
  # confirmation that the terminal authorization was voided.
  #
  # Voided tenders remain on the transaction for audit; they are excluded from
  # settlement (not unresolved / not completed).
  class RecordVoidedCardTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error)

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      direction: "received",
      authorization_code: nil,
      terminal_reference: nil,
      reference_1: nil,
      reference_2: nil,
      external_void_confirmed: false,
      external_void_reference: nil,
      void_reason: nil
    )
      @pos_transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @direction = direction.to_s
      @authorization_code = authorization_code
      @terminal_reference = terminal_reference
      @reference_1 = reference_1
      @reference_2 = reference_2
      @external_void_confirmed = ActiveModel::Type::Boolean.new.cast(external_void_confirmed)
      @external_void_reference = external_void_reference.presence
      @void_reason = void_reason.presence || "amount not attachable; external void confirmed"
    end

    def call
      raise Error, "transaction is not open" unless @pos_transaction.open?
      raise Error, "tender type must be card" unless @tender_type.tender_category == "card"
      raise Error, "amount must be positive" unless @amount_cents.positive?
      raise Error, "direction must be received or refunded" unless %w[received refunded].include?(@direction)
      raise Error, "external_void_confirmed is required" unless @external_void_confirmed
      TenderGuards.assert_active!(@tender_type)

      if @direction == "received"
        TenderGuards.assert_payment_enabled!(@tender_type)
      else
        TenderGuards.assert_refund_enabled!(@tender_type)
      end

      refs = ValidateTenderReferences.call(
        tender_type: @tender_type,
        reference_1: @reference_1,
        reference_2: @reference_2,
        authorization_code: @authorization_code,
        terminal_reference: @terminal_reference
      )

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open" unless transaction.open?

        now = Time.current
        tender = PosTender.create!(
          pos_transaction: transaction,
          store: transaction.store,
          tender_type: @tender_type,
          direction: @direction,
          status: "voided",
          amount_cents: @amount_cents,
          authorization_code: refs.authorization_code,
          terminal_reference: refs.terminal_reference,
          authorized_at: now,
          voided_at: now,
          voided_by_user: @actor,
          void_reason: @void_reason,
          external_void_confirmed_at: now,
          external_void_confirmed_by_user: @actor,
          external_void_reference: @external_void_reference,
          created_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: transaction.store.organization,
          store: transaction.store,
          action: "pos_tender.card_voided_unattached",
          subject: tender,
          metadata: {
            "pos_transaction_id" => transaction.id,
            "direction" => @direction,
            "amount_cents" => @amount_cents,
            "authorization_code" => refs.authorization_code,
            "terminal_reference" => refs.terminal_reference,
            "external_void_reference" => @external_void_reference,
            "void_reason" => @void_reason
          }
        )

        Result.new(pos_tender: tender, success?: true, error: nil)
      end
    rescue Error, ValidateTenderReferences::Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message)
    end
  end
end
