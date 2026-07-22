# frozen_string_literal: true

module Pos
  # Clears a Tender to unlock commercial editing (domain "Tender-state lock"):
  # a `pending` Tender is simply removed; an `authorized` standalone-card Tender
  # must be voided via VoidCardTender after external void confirmation.
  class RemoveTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error)

    def initialize(pos_tender:, actor:, reason: nil, external_void_confirmed: false,
                   external_void_reference: nil)
      @pos_tender = pos_tender
      @actor = actor
      @reason = reason
      @external_void_confirmed = external_void_confirmed
      @external_void_reference = external_void_reference
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_tender.pos_transaction_id)
        unless %w[open suspended].include?(transaction.status)
          raise Error, "transaction is not open"
        end

        tender = PosTender.lock.find(@pos_tender.id)

        case tender.status
        when "pending"
          tender.update!(status: "removed", removed_at: Time.current, removed_by_user: @actor, remove_reason: @reason)
          Result.new(pos_tender: tender, success?: true, error: nil)
        when "authorized"
          unless tender.tender_type.tender_category == "card"
            raise Error, "only authorized card tenders require external void confirmation"
          end

          voided = VoidCardTender.call(
            pos_tender: tender,
            actor: @actor,
            reason: @reason,
            external_void_confirmed: @external_void_confirmed,
            external_void_reference: @external_void_reference
          )
          raise Error, voided.error unless voided.success?

          Result.new(pos_tender: voided.pos_tender, success?: true, error: nil)
        else
          raise Error, "tender is not pending or authorized"
        end
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message)
    end
  end
end
