# frozen_string_literal: true

module Pos
  # Explicit resolution for a late-authorized post-void card orphan before any
  # further terminal operation is allowed against the same original tender.
  #
  # Outcomes:
  # - external_void_confirmed: external refund/void itself was reversed
  # - adopt_as_confirmation: use this auth as the consumable recorded confirmation
  # - accepted_financial_exception: accept stranded external fact with exception approval
  class ResolvePostVoidCardOrphan < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:preparation, :success?, :error)

    KINDS = %i[external_void_confirmed adopt_as_confirmation accepted_financial_exception].freeze
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
      @external_void_reference = external_void_reference.to_s.strip.presence
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
    end

    def call
      raise Error, "unsupported resolution kind" unless KINDS.include?(@resolution_kind)
      raise Error, "resolution reason is required" if @reason.blank?

      ActiveRecord::Base.transaction do
        original_id = PosPostVoidCardPreparation.where(id: @preparation.id)
          .pick(:original_pos_transaction_id)
        raise Error, "preparation not found" if original_id.blank?

        original = PosTransaction.lock.find(original_id)
        preparation = PosPostVoidCardPreparation.lock.find(@preparation.id)
        raise Error, "preparation is not an unresolved orphan" unless preparation.unresolved_orphan?

        assert_permission!(preparation.store, RECONCILE_PERMISSION)

        case @resolution_kind
        when :external_void_confirmed
          resolve_external_void!(preparation)
        when :adopt_as_confirmation
          adopt_as_confirmation!(preparation, original)
        when :accepted_financial_exception
          resolve_financial_exception!(preparation, original)
        end

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: preparation.store.organization,
          store: preparation.store,
          action: "pos_post_void_card.orphan_resolved",
          subject: preparation,
          metadata: {
            "resolution_kind" => @resolution_kind.to_s,
            "reason" => @reason,
            "external_void_reference" => preparation.external_void_reference,
            "status" => preparation.status,
            "original_pos_tender_id" => preparation.original_pos_tender_id,
            "resolution_pos_approval_id" => preparation.resolution_pos_approval_id
          }
        )

        Result.new(preparation: preparation, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(preparation: nil, success?: false, error: e.message)
    end

    private

    def resolve_external_void!(preparation)
      assert_permission!(preparation.store, "pos.tender.card_void")
      raise Error, "external void reference is required" if @external_void_reference.blank?

      preparation.update!(
        resolution_kind: "external_void_confirmed",
        resolved_at: Time.current,
        resolved_by_user: @actor,
        resolution_reason: @reason,
        external_void_reference: @external_void_reference
      )
    end

    def adopt_as_confirmation!(preparation, original)
      parent = PosPostVoidPreparation.lock.find_by(
        original_pos_transaction_id: original.id,
        status: "approved"
      )
      raise Error, "approved post-void preparation required to adopt orphan as confirmation" if parent.blank?

      if PosPostVoidCardPreparation.active.exists?(
        original_pos_tender_id: preparation.original_pos_tender_id
      )
        raise Error, "an active post-void card confirmation already exists for this tender"
      end

      tender = PosTender.lock.find(preparation.original_pos_tender_id)
      raise Error, "orphan amount does not match original tender" unless
        preparation.amount_cents == tender.amount_cents

      preparation.update!(
        status: "recorded",
        pos_post_void_preparation: parent,
        abandoned_at: nil,
        abandoned_by_user: nil,
        resolution_kind: "adopt_as_confirmation",
        resolved_at: nil,
        resolved_by_user: nil,
        resolution_reason: @reason,
        resolution_pos_approval: nil,
        external_void_reference: @external_void_reference || preparation.external_void_reference
      )
    end

    def resolve_financial_exception!(preparation, original)
      approval = authorize_acceptance_exception!(original, preparation)
      preparation.update!(
        resolution_kind: "accepted_financial_exception",
        resolved_at: Time.current,
        resolved_by_user: @actor,
        resolution_reason: @reason,
        resolution_pos_approval: approval,
        external_void_reference: @external_void_reference
      )
    end

    def authorize_acceptance_exception!(original, preparation)
      approver = @exception_approver || @actor
      auth = AuthorizeAction.call(
        store: preparation.store,
        requester: @actor,
        permission_key: RECONCILE_PERMISSION,
        action_type: "card_refund_reconciliation",
        reason: @reason,
        approval_mode: :always,
        approver: approver,
        approver_pin: @exception_approver_pin,
        approver_permission_key: EXCEPTION_APPROVER_PERMISSION,
        self_approver_permission_key: EXCEPTION_APPROVER_PERMISSION,
        pos_transaction: original,
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
