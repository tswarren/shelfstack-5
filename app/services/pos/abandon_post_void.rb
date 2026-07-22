# frozen_string_literal: true

module Pos
  # Abandons an approved post-void plan when no card confirmation has been
  # recorded yet. Prepared card children are abandoned with the parent.
  class AbandonPostVoid < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    def initialize(preparation:, actor:, reason: nil)
      @preparation = preparation
      @actor = actor
      @reason = reason.to_s.strip.presence
    end

    def call
      ActiveRecord::Base.transaction do
        original_id = PosPostVoidPreparation.where(id: @preparation.id)
          .pick(:original_pos_transaction_id)
        raise Error, "preparation not found" if original_id.blank?

        # Lock order: original transaction → parent → children (matches record/post-void).
        PosTransaction.lock.find(original_id)
        preparation = PosPostVoidPreparation.lock.find(@preparation.id)
        raise Error, "only approved post-void preparations can be abandoned" unless preparation.approved?

        children = preparation.pos_post_void_card_preparations.lock.order(:id).to_a
        if children.any? { |c| c.recorded? || c.consumed? || c.recorded_orphan? }
          raise Error, "cannot abandon — card confirmation already recorded; reconcile orphans instead"
        end

        now = Time.current
        children.select(&:prepared?).each do |child|
          child.update!(
            status: "abandoned",
            abandoned_at: now,
            abandoned_by_user: @actor
          )
        end

        preparation.update!(
          status: "abandoned",
          abandoned_at: now,
          abandoned_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: preparation.store.organization,
          store: preparation.store,
          action: "pos_post_void.abandoned",
          subject: preparation,
          metadata: { "reason" => @reason }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end
  end
end
