# frozen_string_literal: true

module Pos
  # Clears a Tender to unlock commercial editing (domain "Tender-state lock"):
  # a `pending` Tender is simply removed; an `authorized` standalone-card Tender
  # may only be `voided` after the cashier explicitly confirms the external
  # terminal void (and supplies a void reference when available).
  #
  # Voiding a card refund that has a linked preparation also resolves that
  # preparation as externally_voided so it cannot fall out of the recon lifecycle.
  #
  # Linked refund tenders lock the original sale transaction and tender before
  # mutating, matching CompletionLockOrder so concurrent completion cannot
  # treat an in-flight refund as durable capacity.
  class RemoveTender < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :success?, :error)

    def initialize(pos_tender:, actor:, reason: nil, external_void_confirmed: false,
                   external_void_reference: nil, resolve_card_refund_preparation: true)
      @pos_tender = pos_tender
      @actor = actor
      @reason = reason
      @external_void_confirmed = ActiveModel::Type::Boolean.new.cast(external_void_confirmed)
      @external_void_reference = external_void_reference.presence
      @resolve_card_refund_preparation = ActiveModel::Type::Boolean.new.cast(resolve_card_refund_preparation)
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_tender.pos_transaction_id)
        unless %w[open suspended].include?(transaction.status)
          raise Error, "transaction is not open"
        end
        TenderGuards.assert_no_outstanding_card_refund_preparation!(transaction)

        tender = PosTender.lock.find(@pos_tender.id)
        lock_original_refund_target!(tender)

        case tender.status
        when "pending"
          tender.update!(status: "removed", removed_at: Time.current, removed_by_user: @actor, remove_reason: @reason)
        when "authorized"
          void_authorized_card!(tender)
          resolve_linked_preparation!(transaction, tender) if @resolve_card_refund_preparation
        else
          raise Error, "tender is not pending or authorized"
        end

        Result.new(pos_tender: tender, success?: true, error: nil)
      end
    rescue Error, TenderGuards::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, success?: false, error: e.message)
    end

    private

    def lock_original_refund_target!(tender)
      return if tender.original_pos_tender_id.blank?

      original = PosTender.find(tender.original_pos_tender_id)
      PosTransaction.lock.find(original.pos_transaction_id)
      PosTender.lock.find(original.id)
    end

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

    def resolve_linked_preparation!(transaction, tender)
      preparation = PosCardRefundPreparation.lock.find_by(pos_tender_id: tender.id)
      return if preparation.blank?
      return unless preparation.recorded_tender?
      return if preparation.resolved_at.present?

      preparation.update!(
        resolution_kind: "externally_voided",
        resolved_at: Time.current,
        resolved_by_user: @actor,
        resolution_reason: @reason.presence || "card tender voided",
        external_void_reference: @external_void_reference,
        requires_reconciliation: false
      )

      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: transaction.store.organization,
        store: transaction.store,
        action: "pos_card_refund.tender_reconciliation_resolved",
        subject: preparation,
        metadata: {
          "preparation_id" => preparation.id,
          "pos_tender_id" => tender.id,
          "outcome" => "externally_voided",
          "reason" => preparation.resolution_reason,
          "external_void_reference" => @external_void_reference,
          "via" => "remove_tender"
        }
      )
    end
  end
end
