# frozen_string_literal: true

module Pos
  # Cash accountability movement (domain "Cash accountability"): additional_float,
  # paid_in, paid_out, safe_drop, etc. Session-scoped, not Transaction-scoped.
  # `Cash Movement Type#requires_approval` gates independent-approver escalation via
  # `Pos::AuthorizeAction` against `maximum_paid_out_cents` (the only Phase 4c
  # numeric authority key for this permission per the permission catalog).
  class CreateCashMovement < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_cash_movement, :success?, :error, :pos_approval)

    def initialize(pos_session:, cash_movement_type:, amount_cents:, actor:, reason: nil, reference: nil,
                    approver: nil, approver_pin: nil)
      @pos_session = pos_session
      @cash_movement_type = cash_movement_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @reason = reason
      @reference = reference
      @approver = approver
      @approver_pin = approver_pin
    end

    def call
      raise Error, "session is not open" unless @pos_session.open?
      raise Error, "amount must be positive" unless @amount_cents.positive?
      raise Error, "reference is required" if @cash_movement_type.requires_reference && @reference.blank?

      store = @pos_session.store
      authorization = Pos::AuthorizeAction.call(
        store: store,
        requester: @actor,
        permission_key: "pos.cash_movement.create",
        approver_permission_key: "pos.cash_movement.create",
        action_type: "cash_movement",
        limit_key: @cash_movement_type.requires_approval ? :maximum_paid_out_cents : nil,
        requested_value: @amount_cents,
        reason: @reason,
        approver: @approver,
        approver_pin: @approver_pin,
        pos_session: @pos_session
      )
      return unauthorized_result(authorization) unless authorization.allowed?

      ActiveRecord::Base.transaction do
        movement = PosCashMovement.create!(
          store: store, pos_session: @pos_session, cash_movement_type: @cash_movement_type,
          amount_cents: @amount_cents, reason: @reason, reference: @reference,
          created_by_user: @actor, approved_by_user: authorization.pos_approval&.approved_by_user,
          pos_approval: authorization.pos_approval, created_at: Time.current
        )

        Administration::RecordAuditEvent.call(
          actor: @actor, organization: store.organization, store: store,
          action: "pos_cash_movement.created", subject: movement,
          metadata: {
            "cash_movement_type" => @cash_movement_type.code, "amount_cents" => @amount_cents,
            "approved_by_user_id" => authorization.pos_approval&.approved_by_user_id
          }
        )

        Result.new(pos_cash_movement: movement, success?: true, error: nil, pos_approval: authorization.pos_approval)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_cash_movement: nil, success?: false, error: e.message, pos_approval: nil)
    end

    private

    def unauthorized_result(authorization)
      error = case authorization.status
      when :requires_approval then "cash movement exceeds authority and requires approval"
      else authorization.error || "cash movement denied"
      end
      Result.new(pos_cash_movement: nil, success?: false, error: error, pos_approval: nil)
    end
  end
end
