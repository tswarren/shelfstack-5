# frozen_string_literal: true

module Inventory
  class CancelAdjustment < ApplicationService
    Result = Data.define(:adjustment, :success?, :error)

    def initialize(adjustment:, actor:, store:, cancel_note:)
      @adjustment = adjustment
      @actor = actor
      @store = store
      @cancel_note = cancel_note
    end

    def call
      ActiveRecord::Base.transaction do
        @adjustment.lock!
        return failure("only draft adjustments can be cancelled") unless @adjustment.draft?
        return failure("adjustment store mismatch") unless @adjustment.store_id == @store.id
        return failure("cancel note is required") if @cancel_note.blank?

        own_draft = @adjustment.created_by_user_id == @actor.id
        can_create = Authorization::EvaluatePermission.call(
          user: @actor, store: @store, permission_key: "inventory.adjustment.create"
        ) == :allow
        can_post = Authorization::EvaluatePermission.call(
          user: @actor, store: @store, permission_key: "inventory.adjustment.post"
        ) == :allow

        unless (own_draft && can_create) || can_post
          return failure("not permitted to cancel this adjustment")
        end

        @adjustment.update!(
          status: "cancelled",
          cancelled_by_user: @actor,
          cancelled_at: Time.current,
          cancel_note: @cancel_note
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "inventory.adjustment.cancelled",
          subject: @adjustment,
          metadata: { "cancel_note" => @cancel_note }
        )

        Result.new(adjustment: @adjustment, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def failure(message)
      Result.new(adjustment: @adjustment, success?: false, error: message)
    end
  end
end
