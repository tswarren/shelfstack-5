# frozen_string_literal: true

module Pos
  # Voids an existing authorized card tender after the operator confirms the
  # external terminal void. The tender remains on the transaction as voided
  # (excluded from settlement); it is not removed.
  class VoidCardTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error)

    def initialize(pos_tender:, actor:, reason: nil, external_void_confirmed: false,
                   external_void_reference: nil)
      @pos_tender = pos_tender
      @actor = actor
      @reason = reason
      @external_void_confirmed = ActiveModel::Type::Boolean.new.cast(external_void_confirmed)
      @external_void_reference = external_void_reference.presence
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_tender.pos_transaction_id)
        unless %w[open suspended].include?(transaction.status)
          raise Error, "transaction is not open"
        end

        tender = PosTender.lock.find(@pos_tender.id)
        lock_original_refund_target!(tender)

        unless tender.authorized?
          raise Error, "tender is not authorized"
        end
        unless tender.tender_type.tender_category == "card"
          raise Error, "only authorized card tenders can be voided with VoidCardTender"
        end

        unless Authorization::EvaluatePermission.call(
          user: @actor, store: tender.store, permission_key: "pos.tender.card_void"
        ) == :allow
          raise Error, "missing permission pos.tender.card_void"
        end

        unless @external_void_confirmed
          raise Error, "authorized card tender requires external_void_confirmed before voiding"
        end

        now = Time.current
        tender.update!(
          status: "voided",
          voided_at: now,
          voided_by_user: @actor,
          void_reason: @reason,
          external_void_confirmed_at: now,
          external_void_confirmed_by_user: @actor,
          external_void_reference: @external_void_reference
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: transaction.store.organization,
          store: transaction.store,
          action: "pos_tender.card_voided",
          subject: tender,
          metadata: {
            "pos_transaction_id" => transaction.id,
            "amount_cents" => tender.amount_cents,
            "authorization_code" => tender.authorization_code,
            "terminal_reference" => tender.terminal_reference,
            "external_void_reference" => @external_void_reference,
            "void_reason" => @reason
          }
        )

        Result.new(pos_tender: tender, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message)
    end

    private

    def lock_original_refund_target!(tender)
      return if tender.original_pos_tender_id.blank?

      original = PosTender.find(tender.original_pos_tender_id)
      PosTransaction.lock.find(original.pos_transaction_id)
      PosTender.lock.find(original.id)
    end
  end
end
