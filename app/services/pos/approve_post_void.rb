# frozen_string_literal: true

module Pos
  # Policy A step 1: authorize the complete post-void operation (ShelfStack
  # correction + permission to reverse funds on the terminal). Persists a
  # PosApproval only — no preparation tables.
  class ApprovePostVoid < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_approval, :reason, :success?, :error)

    def initialize(original_transaction:, actor:, reason:, approver: nil, approver_pin: nil, pos_session: nil)
      @original = original_transaction
      @actor = actor
      @reason = reason.to_s.strip
      @approver = approver
      @approver_pin = approver_pin
      @pos_session = pos_session
    end

    def call
      raise Error, "reason is required" if @reason.blank?
      raise Error, "only completed transactions can be post-voided" unless @original.completed?
      raise Error, "transaction has already been post-voided" if @original.post_voided?

      eligibility = EvaluatePostVoidEligibility.call(
        original_transaction: @original, store: @original.store
      )
      raise Error, eligibility.blockers.join(", ") unless eligibility.eligible?

      auth = AuthorizeAction.call(
        store: @original.store,
        requester: @actor,
        permission_key: "pos.post_void.create",
        approver_permission_key: "pos.post_void.approve",
        self_approver_permission_key: "pos.post_void.approve_self",
        action_type: "post_void",
        approval_mode: :always,
        reason: @reason,
        approver: @approver,
        approver_pin: @approver_pin,
        pos_transaction: @original,
        pos_session: @pos_session
      )
      raise Error, auth.error unless auth.allowed?

      Result.new(pos_approval: auth.pos_approval, reason: @reason, success?: true, error: nil)
    rescue Error => e
      Result.new(pos_approval: nil, reason: nil, success?: false, error: e.message)
    end
  end
end
