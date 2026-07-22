# frozen_string_literal: true

module Pos
  # Resolves an authorized card-refund tender that requires reconciliation.
  # Outcomes are explicit — there is no generic "clear" flag.
  class ResolveCardRefundTenderReconciliation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tender, :preparation, :success?, :error)

    OUTCOMES = %i[externally_voided validated_and_accepted replaced].freeze
    RECONCILE_PERMISSION = "pos.card_refund.reconcile"
    EXCEPTION_APPROVER_PERMISSION = "pos.return.refund_exception.approve"

    def initialize(
      preparation: nil,
      pos_tender: nil,
      actor:,
      outcome:,
      reason:,
      external_void_reference: nil,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @preparation = preparation
      @pos_tender = pos_tender
      @actor = actor
      @outcome = outcome.to_sym
      @reason = reason.to_s.strip
      @external_void_reference = external_void_reference.presence
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
    end

    def call
      raise Error, "unsupported outcome" unless OUTCOMES.include?(@outcome)
      raise Error, "resolution reason is required" if @reason.blank?

      ActiveRecord::Base.transaction do
        preparation = resolve_preparation!
        transaction = PosTransaction.lock.find(preparation.pos_transaction_id)
        preparation = PosCardRefundPreparation.lock.find(preparation.id)
        tender = PosTender.lock.find(preparation.pos_tender_id)
        RefundLockOrder.lock_linked_originals!(transaction)

        raise Error, "preparation is not a recorded tender" unless preparation.recorded_tender?
        raise Error, "tender does not require reconciliation" unless tender.requires_reconciliation?
        raise Error, "tender is not authorized" unless tender.authorized?
        unless %w[open suspended].include?(transaction.status)
          raise Error, "transaction must be open or suspended to resolve tender reconciliation"
        end

        assert_permission!(transaction.store, RECONCILE_PERMISSION)

        case @outcome
        when :externally_voided, :replaced
          assert_permission!(transaction.store, "pos.tender.card_void")
          void_tender!(tender)
          preparation.update!(
            resolution_kind: @outcome.to_s,
            resolved_at: Time.current,
            resolved_by_user: @actor,
            resolution_reason: @reason,
            external_void_reference: @external_void_reference,
            requires_reconciliation: false
          )
        when :validated_and_accepted
          accept_validated!(transaction, preparation, tender)
        end

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: transaction.store.organization,
          store: transaction.store,
          action: "pos_card_refund.tender_reconciliation_resolved",
          subject: preparation,
          metadata: {
            "preparation_id" => preparation.id,
            "pos_tender_id" => tender.id,
            "outcome" => @outcome.to_s,
            "reason" => @reason,
            "external_void_reference" => @external_void_reference,
            "original_pos_tender_id" => tender.reload.original_pos_tender_id,
            "pos_approval_id" => tender.pos_approval_id
          }
        )

        Result.new(pos_tender: tender.reload, preparation: preparation.reload, success?: true, error: nil)
      end
    rescue Error, CardRefundSupport::Error, RefundAllocationPolicy::Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tender: nil, preparation: nil, success?: false, error: e.message)
    end

    private

    def resolve_preparation!
      if @preparation
        @preparation
      elsif @pos_tender
        PosCardRefundPreparation.find_by!(pos_tender_id: @pos_tender.id)
      else
        raise Error, "preparation or pos_tender is required"
      end
    end

    def accept_validated!(transaction, preparation, tender)
      intended = preparation.intended_original_pos_tender
      bind_original = nil
      approval = tender.pos_approval || preparation.pos_approval

      if intended.present?
        begin
          bind_original = CardRefundSupport.validate_original!(
            transaction: transaction,
            original_pos_tender: intended,
            amount_cents: tender.amount_cents,
            excluding_refund_tender: tender
          )
        rescue CardRefundSupport::Error
          bind_original = nil
        end
      end

      if bind_original.present?
        tender.update!(
          requires_reconciliation: false,
          original_pos_tender: bind_original,
          pos_approval: approval
        )
      else
        approval = authorize_acceptance_exception!(transaction, tender)
        tender.update!(
          requires_reconciliation: false,
          original_pos_tender: nil,
          pos_approval: approval
        )
      end

      RefundAllocationPolicy.validate_plan!(pos_transaction: transaction, actor: @actor)

      preparation.update!(
        resolution_kind: "validated_and_accepted",
        resolved_at: Time.current,
        resolved_by_user: @actor,
        resolution_reason: @reason,
        requires_reconciliation: false,
        reconciliation_reasons: []
      )
    end

    def authorize_acceptance_exception!(transaction, tender)
      approver = @exception_approver || @actor
      auth = AuthorizeAction.call(
        store: transaction.store,
        requester: @actor,
        permission_key: RECONCILE_PERMISSION,
        action_type: "card_refund_reconciliation",
        reason: @reason,
        approval_mode: :always,
        approver: approver,
        approver_pin: @exception_approver_pin,
        approver_permission_key: EXCEPTION_APPROVER_PERMISSION,
        self_approver_permission_key: EXCEPTION_APPROVER_PERMISSION,
        pos_transaction: transaction,
        requested_value: tender.amount_cents
      )
      return auth.pos_approval if auth.allowed? && auth.pos_approval

      raise Error, auth.error || "card refund acceptance requires exception approval"
    end

    def void_tender!(tender)
      removed = RemoveTender.call(
        pos_tender: tender,
        actor: @actor,
        reason: @reason,
        external_void_confirmed: true,
        external_void_reference: @external_void_reference,
        resolve_card_refund_preparation: true
      )
      raise Error, removed.error unless removed.success?
    end

    def assert_permission!(store, key)
      unless Authorization::EvaluatePermission.call(
        user: @actor, store: store, permission_key: key
      ) == :allow
        raise Error, "missing permission #{key}"
      end
    end
  end
end
