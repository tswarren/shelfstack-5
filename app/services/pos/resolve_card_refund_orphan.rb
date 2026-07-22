# frozen_string_literal: true

module Pos
  # Resolves a recorded_orphan external card refund with an explicit outcome.
  # linked_to_correcting_transaction is deferred until a formal correcting-
  # transaction model exists.
  class ResolveCardRefundOrphan < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    KINDS = %i[external_void_confirmed accepted_financial_exception].freeze
    RECONCILE_PERMISSION = "pos.card_refund.reconcile"
    EXCEPTION_APPROVER_PERMISSION = "pos.return.refund_exception.approve"

    def initialize(
      preparation:,
      actor:,
      resolution_kind:,
      reason:,
      external_void_reference: nil,
      exception_approver: nil,
      exception_approver_pin: nil
    )
      @preparation = preparation
      @actor = actor
      @resolution_kind = resolution_kind.to_sym
      @reason = reason.to_s.strip
      @external_void_reference = external_void_reference.presence
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
    end

    def call
      raise Error, "unsupported resolution kind" unless KINDS.include?(@resolution_kind)
      raise Error, "resolution reason is required" if @reason.blank?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@preparation.pos_transaction_id)
        preparation = PosCardRefundPreparation.lock.find(@preparation.id)
        raise Error, "preparation is not an unresolved orphan" unless preparation.unresolved_orphan?

        assert_permission!(transaction.store, RECONCILE_PERMISSION)

        case @resolution_kind
        when :external_void_confirmed
          assert_permission!(transaction.store, "pos.tender.card_void")
          raise Error, "external void reference is required" if @external_void_reference.blank?
        when :accepted_financial_exception
          authorize_acceptance_exception!(transaction, preparation)
        end

        preparation.update!(
          resolution_kind: @resolution_kind.to_s,
          resolved_at: Time.current,
          resolved_by_user: @actor,
          resolution_reason: @reason,
          external_void_reference: @external_void_reference,
          requires_reconciliation: false
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: transaction.store.organization,
          store: transaction.store,
          action: "pos_card_refund.orphan_resolved",
          subject: preparation,
          metadata: {
            "preparation_id" => preparation.id,
            "resolution_kind" => @resolution_kind.to_s,
            "reason" => @reason,
            "external_void_reference" => @external_void_reference,
            "intended_original_pos_tender_id" => preparation.intended_original_pos_tender_id,
            "authorization_code" => preparation.authorization_code,
            "abandoned_at" => preparation.abandoned_at,
            "abandoned_by_user_id" => preparation.abandoned_by_user_id
          }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end

    private

    def authorize_acceptance_exception!(transaction, preparation)
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
        requested_value: preparation.amount_cents
      )
      return auth.pos_approval if auth.allowed? && auth.pos_approval

      raise Error, auth.error || "financial exception acceptance requires exception approval"
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
