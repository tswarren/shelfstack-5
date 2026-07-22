# frozen_string_literal: true

module Pos
  # Creates a durable post-void card preparation for one tender under an
  # approved parent plan. Normally children are created by PreparePostVoid;
  # this recreates a prepared child after abandon.
  class PreparePostVoidCardConfirmation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    def initialize(original_pos_tender:, actor:, pos_post_void_preparation: nil)
      @original_pos_tender = original_pos_tender
      @actor = actor
      @pos_post_void_preparation = pos_post_void_preparation
    end

    def call
      tender = @original_pos_tender
      raise Error, "tender is required" if tender.blank?
      raise Error, "tender must be completed" unless tender.completed?
      raise Error, "tender must be card" unless tender.tender_type.tender_category == "card"

      original = tender.pos_transaction
      raise Error, "original transaction must be completed" unless original.completed?
      raise Error, "original transaction already post-voided" if original.post_voided?

      unless Authorization::EvaluatePermission.call(
        user: @actor, store: original.store, permission_key: "pos.post_void.create"
      ) == :allow
        raise Error, "missing permission pos.post_void.create"
      end

      ActiveRecord::Base.transaction do
        PosTransaction.lock.find(original.id)
        locked_tender = PosTender.lock.find(tender.id)
        raise Error, "tender must be completed" unless locked_tender.completed?

        parent = resolve_parent!(original)
        raise Error, "approved post-void preparation required before card confirmation" unless parent&.approved?

        if PosPostVoidCardPreparation.active.exists?(original_pos_tender_id: locked_tender.id)
          raise Error, "an active post-void card preparation already exists for this tender"
        end
        if PosPostVoidCardPreparation.unresolved_orphans.exists?(original_pos_tender_id: locked_tender.id)
          raise Error,
                "unresolved post-void card orphan exists for this tender — resolve it before another terminal operation"
        end

        preparation = PosPostVoidCardPreparation.create!(
          pos_post_void_preparation: parent,
          original_pos_transaction: original,
          original_pos_tender: locked_tender,
          store: original.store,
          prepared_by_user: @actor,
          amount_cents: locked_tender.amount_cents,
          status: "prepared",
          expires_at: Time.current + PosPostVoidCardPreparation::TTL
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: original.store.organization,
          store: original.store,
          action: "pos_post_void_card.prepared",
          subject: preparation,
          metadata: {
            "original_pos_transaction_id" => original.id,
            "original_pos_tender_id" => locked_tender.id,
            "pos_post_void_preparation_id" => parent.id,
            "amount_cents" => locked_tender.amount_cents
          }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end

    private

    def resolve_parent!(original)
      if @pos_post_void_preparation.present?
        parent = PosPostVoidPreparation.lock.find(@pos_post_void_preparation.id)
        raise Error, "preparation does not belong to this transaction" unless
          parent.original_pos_transaction_id == original.id
        return parent
      end

      PosPostVoidPreparation.lock.find_by(
        original_pos_transaction_id: original.id,
        status: "approved"
      )
    end
  end
end
