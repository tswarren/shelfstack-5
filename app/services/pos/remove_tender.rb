# frozen_string_literal: true

module Pos
  # Clears a Tender to unlock commercial editing (domain "Tender-state lock"): a
  # `pending` Tender is simply removed; an `authorized` standalone-card Tender is
  # `voided`, representing the cashier's confirmation of the required external void.
  class RemoveTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error)

    def initialize(pos_tender:, actor:, reason: nil)
      @pos_tender = pos_tender
      @actor = actor
      @reason = reason
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
          tender.update!(status: "voided", voided_at: Time.current, voided_by_user: @actor, void_reason: @reason)
        else
          raise Error, "tender is not pending or authorized"
        end

        Result.new(pos_tender: tender, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message)
    end
  end
end
