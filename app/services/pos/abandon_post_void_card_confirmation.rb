# frozen_string_literal: true

module Pos
  class AbandonPostVoidCardConfirmation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    def initialize(preparation:, actor:, reason: nil)
      @preparation = preparation
      @actor = actor
      @reason = reason.to_s.strip.presence
    end

    def call
      ActiveRecord::Base.transaction do
        original_id = PosPostVoidCardPreparation.where(id: @preparation.id)
          .pick(:original_pos_transaction_id)
        raise Error, "preparation not found" if original_id.blank?

        PosTransaction.lock.find(original_id)
        preparation = PosPostVoidCardPreparation.lock.find(@preparation.id)
        raise Error, "only prepared confirmations can be abandoned" unless preparation.prepared?

        preparation.update!(
          status: "abandoned",
          abandoned_at: Time.current,
          abandoned_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: preparation.store.organization,
          store: preparation.store,
          action: "pos_post_void_card.abandoned",
          subject: preparation,
          metadata: {
            "original_pos_tender_id" => preparation.original_pos_tender_id,
            "reason" => @reason
          }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end
  end
end
