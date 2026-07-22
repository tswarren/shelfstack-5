# frozen_string_literal: true

module Pos
  # Explicitly abandons an outstanding card-refund preparation before any
  # external authorization is recorded. TTL never auto-abandons.
  class AbandonCardRefundPreparation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    def initialize(preparation:, actor:, reason: nil)
      @preparation = preparation
      @actor = actor
      @reason = reason
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@preparation.pos_transaction_id)
        preparation = PosCardRefundPreparation.lock.find(@preparation.id)
        raise Error, "preparation does not belong to this transaction" unless preparation.pos_transaction_id == transaction.id
        raise Error, "preparation is not outstanding" unless preparation.prepared?
        raise Error, "preparation already has an authorization" if preparation.authorization_code.present?

        stale = preparation.expires_at <= Time.current
        preparation.update!(
          status: "abandoned",
          abandoned_at: Time.current,
          abandoned_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: transaction.store.organization,
          store: transaction.store,
          action: "pos_card_refund.preparation_abandoned",
          subject: preparation,
          metadata: {
            "preparation_id" => preparation.id,
            "reason" => @reason,
            "stale" => stale
          }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end
  end
end
