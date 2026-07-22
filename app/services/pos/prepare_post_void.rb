# frozen_string_literal: true

module Pos
  # Approves a durable post-void plan before any terminal card confirmation.
  # Eagerly creates prepared card children so the UI can proceed to the terminal
  # in one step after approval.
  class PreparePostVoid < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    def initialize(
      original_transaction:,
      actor:,
      reason:,
      approver:,
      approver_pin:,
      pos_session: nil
    )
      @original = original_transaction
      @actor = actor
      @reason = reason.to_s.strip
      @approver = approver
      @approver_pin = approver_pin
      @pos_session = pos_session
    end

    def call
      raise Error, "post_void_reason is required" if @reason.blank?
      raise Error, "original transaction must be completed" unless @original.completed?
      raise Error, "original transaction already post-voided" if @original.post_voided?

      ActiveRecord::Base.transaction do
        original = PosTransaction.lock.find(@original.id)
        raise Error, "original transaction must be completed" unless original.completed?
        raise Error, "original transaction already post-voided" if original.post_voided?

        if PosPostVoidPreparation.approved.exists?(original_pos_transaction_id: original.id)
          raise Error, "an approved post-void preparation already exists for this transaction"
        end
        if PosPostVoidCardPreparation.unresolved_orphans.exists?(original_pos_transaction_id: original.id)
          raise Error,
                "unresolved post-void card orphan exists — resolve it before preparing a new plan"
        end

        eligibility = EvaluatePostVoidEligibility.call(
          original_transaction: original, store: original.store
        )
        raise Error, eligibility.blockers.join(", ") unless eligibility.eligible?

        auth = AuthorizeAction.call(
          store: original.store,
          requester: @actor,
          permission_key: "pos.post_void.create",
          action_type: "post_void",
          reason: @reason,
          approval_mode: :always,
          approver: @approver,
          approver_pin: @approver_pin,
          approver_permission_key: "pos.post_void.approve",
          self_approver_permission_key: "pos.post_void.approve_self",
          pos_transaction: original,
          pos_session: @pos_session
        )
        raise Error, auth.error || "post-void approval required" unless auth.allowed? && auth.pos_approval

        snapshot = PostVoidPlanSnapshot.build(original)
        preparation = PosPostVoidPreparation.create!(
          original_pos_transaction: original,
          store: original.store,
          prepared_by_user: @actor,
          pos_approval: auth.pos_approval,
          reason: @reason,
          status: "approved",
          commercial_snapshot: snapshot,
          commercial_fingerprint: PostVoidPlanSnapshot.fingerprint(snapshot),
          fingerprint_version: PostVoidPlanSnapshot::VERSION
        )

        card_tenders = original.pos_tenders.where(status: "completed").select { |t|
          t.tender_type.tender_category == "card"
        }
        expires_at = Time.current + PosPostVoidCardPreparation::TTL
        card_tenders.each do |tender|
          PosPostVoidCardPreparation.create!(
            pos_post_void_preparation: preparation,
            original_pos_transaction: original,
            original_pos_tender: tender,
            store: original.store,
            prepared_by_user: @actor,
            amount_cents: tender.amount_cents,
            status: "prepared",
            expires_at: expires_at
          )
        end

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: original.store.organization,
          store: original.store,
          action: "pos_post_void.prepared",
          subject: preparation,
          metadata: {
            "original_pos_transaction_id" => original.id,
            "pos_approval_id" => auth.pos_approval.id,
            "card_preparation_count" => card_tenders.size,
            "commercial_fingerprint" => preparation.commercial_fingerprint
          }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end
  end
end
