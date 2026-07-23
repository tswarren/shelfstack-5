# frozen_string_literal: true

module Pos
  # Confirms external void of a durable `void_required` card tender and
  # transitions it to `voided`. Resolvable regardless of transaction status or
  # whether the tender type remains active / payment-/refund-enabled.
  class RecordVoidedCardTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error)

    def initialize(
      pos_tender:,
      actor:,
      external_void_confirmed: false,
      external_void_reference: nil,
      void_reason: nil
    )
      @pos_tender = pos_tender
      @actor = actor
      @external_void_confirmed = ActiveModel::Type::Boolean.new.cast(external_void_confirmed)
      @external_void_reference = external_void_reference.presence
      @void_reason = void_reason
    end

    def call
      unless Authorization::EvaluatePermission.call(
        user: @actor, store: @pos_tender.store, permission_key: "pos.tender.card_void"
      ) == :allow
        raise Error, "missing permission pos.tender.card_void"
      end

      raise Error, "external_void_confirmed is required" unless @external_void_confirmed

      ActiveRecord::Base.transaction do
        # Lock tender; transaction lock is for ordering only — status may be any.
        PosTransaction.lock.find(@pos_tender.pos_transaction_id)
        tender = PosTender.lock.find(@pos_tender.id)

        if tender.voided?
          return Result.new(pos_tender: tender, success?: true, error: nil)
        end

        unless tender.void_required?
          raise Error, "tender is not awaiting void confirmation"
        end
        unless tender.tender_type.tender_category == "card"
          raise Error, "tender type must be card"
        end

        now = Time.current
        reason = @void_reason.presence || tender.void_reason.presence ||
          "unattachable terminal activity; external void confirmed"

        tender.update!(
          status: "voided",
          voided_at: now,
          voided_by_user: @actor,
          void_reason: reason,
          external_void_confirmed_at: now,
          external_void_confirmed_by_user: @actor,
          external_void_reference: @external_void_reference
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: tender.store.organization,
          store: tender.store,
          action: "pos_tender.card_voided_unattached",
          subject: tender,
          metadata: {
            "pos_transaction_id" => tender.pos_transaction_id,
            "direction" => tender.direction,
            "amount_cents" => tender.amount_cents,
            "authorization_code" => tender.authorization_code,
            "terminal_reference" => tender.terminal_reference,
            "external_void_reference" => @external_void_reference,
            "void_reason" => reason,
            "recording_idempotency_key" => tender.recording_idempotency_key
          }
        )

        Result.new(pos_tender: tender, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message)
    end
  end
end
