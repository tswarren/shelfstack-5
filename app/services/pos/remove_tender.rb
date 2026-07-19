# frozen_string_literal: true

module Pos
  # Clears a Tender to unlock commercial editing (domain "Tender-state lock"):
  # a `pending` Tender is simply removed; an `authorized` standalone-card Tender
  # may only be `voided` after the cashier explicitly confirms the external
  # terminal void (and supplies a void reference when available).
  class RemoveTender < ApplicationService
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
        tender = PosTender.lock.find(@pos_tender.id)
        unless %w[open suspended].include?(tender.pos_transaction.status)
          raise Error, "transaction is not open"
        end

        case tender.status
        when "pending"
          tender.update!(status: "removed", removed_at: Time.current, removed_by_user: @actor, remove_reason: @reason)
        when "authorized"
          void_authorized_card!(tender)
        else
          raise Error, "tender is not pending or authorized"
        end

        Result.new(pos_tender: tender, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message)
    end

    private

    def void_authorized_card!(tender)
      unless tender.tender_type.tender_category == "card"
        raise Error, "only authorized card tenders require external void confirmation"
      end

      unless Authorization::EvaluatePermission.call(
        user: @actor, store: tender.store, permission_key: "pos.tender.card_void"
      ) == :allow
        raise Error, "missing permission pos.tender.card_void"
      end

      unless @external_void_confirmed
        raise Error, "authorized card tender requires external_void_confirmed before voiding"
      end

      tender.update!(
        status: "voided",
        voided_at: Time.current,
        voided_by_user: @actor,
        void_reason: @reason,
        external_void_confirmed_at: Time.current,
        external_void_confirmed_by_user: @actor,
        external_void_reference: @external_void_reference
      )
    end
  end
end
