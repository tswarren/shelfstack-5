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
      exception_approver_pin: nil,
      replacement_pos_tender: nil # ignored; replacement is bound via preparation.replaces_pos_tender
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

        replacement = nil
        case @outcome
        when :externally_voided
          assert_permission!(transaction.store, "pos.tender.card_void")
          raise Error, "external void reference is required" if @external_void_reference.blank?
          void_tender!(tender, resolve_preparation: false)
          preparation.update!(
            resolution_kind: "externally_voided",
            resolved_at: Time.current,
            resolved_by_user: @actor,
            resolution_reason: @reason,
            external_void_reference: @external_void_reference,
            requires_reconciliation: false
          )
        when :replaced
          assert_permission!(transaction.store, "pos.tender.card_void")
          raise Error, "external void reference is required" if @external_void_reference.blank?
          replacement = activate_replacement!(transaction, tender)
          void_tender!(tender, resolve_preparation: false)
          ValidateCompletionReadiness.call(pos_transaction: transaction, actor: @actor)
          preparation.update!(
            resolution_kind: "replaced",
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
            "replacement_pos_tender_id" => replacement&.id,
            "original_pos_tender_id" => tender.reload.original_pos_tender_id,
            "pos_approval_id" => tender.pos_approval_id,
            "resolution_pos_approval_id" => preparation.resolution_pos_approval_id
          }
        )

        Result.new(pos_tender: tender.reload, preparation: preparation.reload, success?: true, error: nil)
      end
    rescue Error, CardRefundSupport::Error, ValidateCompletionReadiness::Error,
           RefundAllocationPolicy::Error, ActiveRecord::RecordInvalid => e
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
      destination_approval = tender.pos_approval || preparation.pos_approval
      resolution_approval = nil

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
          pos_approval: destination_approval
        )
      else
        resolution_approval = authorize_acceptance_exception!(transaction, tender)
        tender.update!(
          requires_reconciliation: false,
          original_pos_tender: nil,
          pos_approval: resolution_approval
        )
      end

      # Full readiness with the prospective clear already applied; rolls back on failure.
      ValidateCompletionReadiness.call(pos_transaction: transaction, actor: @actor)

      preparation.update!(
        resolution_kind: "validated_and_accepted",
        resolved_at: Time.current,
        resolved_by_user: @actor,
        resolution_reason: @reason,
        requires_reconciliation: false,
        reconciliation_reasons: [],
        resolution_pos_approval: resolution_approval
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

    def void_tender!(tender, resolve_preparation:)
      removed = RemoveTender.call(
        pos_tender: tender,
        actor: @actor,
        reason: @reason,
        external_void_confirmed: true,
        external_void_reference: @external_void_reference,
        resolve_card_refund_preparation: resolve_preparation
      )
      raise Error, removed.error unless removed.success?
    end

    # Replacement must be prepared specifically against this recon tender and
    # already authorized. The old tender is voided after the replacement exists;
    # readiness then validates settlement with the replacement alone.
    def activate_replacement!(transaction, tender)
      prep = PosCardRefundPreparation
        .lock
        .where(
          pos_transaction_id: transaction.id,
          replaces_pos_tender_id: tender.id,
          status: "recorded_tender"
        )
        .where(resolved_at: nil)
        .order(:consumed_at)
        .first

      if prep.blank?
        raise Error,
              "replaced requires a recorded replacement preparation " \
              "created against this reconciliation tender"
      end

      replacement = PosTender.lock.find(prep.pos_tender_id)
      unless replacement.authorized? && !replacement.requires_reconciliation?
        raise Error, "replacement tender must be authorized without reconciliation"
      end
      if replacement.amount_cents != tender.amount_cents
        raise Error, "replacement tender amount must match the tender being replaced"
      end

      replacement
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
