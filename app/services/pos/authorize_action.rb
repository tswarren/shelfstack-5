# frozen_string_literal: true

module Pos
  # Shared authorization workflow for Phase 4b restricted POS actions (price override,
  # discount apply, tax exemption, tax category override). Separates permission,
  # numeric authority, and approval per ADR-0011:
  #
  # * the requester must hold `permission_key` to attempt the action at all;
  # * when `limit_key` is present, the requester's own numeric authority governs
  #   whether they may proceed directly or must escalate to an approver;
  # * when `limit_key` is absent, holding `permission_key` is itself sufficient —
  #   escalation is required only when the requester lacks it;
  # * an approver must authenticate with their own credentials, hold
  #   `approver_permission_key` (defaults to `permission_key`), and (for numeric
  #   actions) have their own authority cover the requested value.
  #
  # Does not persist anything for the underlying action itself — callers apply the
  # change only after this returns an `:allowed` or `:approved` status.
  class AuthorizeAction < ApplicationService
    Result = Data.define(:status, :pos_approval, :error) do
      def allowed?
        status == :allowed || status == :approved
      end
    end

    def initialize(store:, requester:, permission_key:, action_type:, reason: nil,
                    limit_key: nil, requested_value: nil,
                    approver: nil, approver_pin: nil, approver_permission_key: nil,
                    pos_transaction: nil, pos_line_item: nil, pos_session: nil)
      @store = store
      @requester = requester
      @permission_key = permission_key.to_s
      @approver_permission_key = (approver_permission_key || permission_key).to_s
      @action_type = action_type
      @reason = reason
      @limit_key = limit_key
      @requested_value = requested_value
      @approver = approver
      @approver_pin = approver_pin
      @pos_transaction = pos_transaction
      @pos_line_item = pos_line_item
      @pos_session = pos_session
    end

    def call
      return escalate_with_approver unless requester_permitted?

      if @limit_key.nil?
        allowed
      else
        authorize_numeric_action
      end
    end

    private

    def authorize_numeric_action
      requester_authority = Authorization::EvaluateAuthority.call(
        user: @requester, store: @store, limit_key: @limit_key, requested_value: @requested_value
      )
      return allowed if requester_authority.allow?

      escalate_with_approver
    end

    def escalate_with_approver
      return Result.new(status: :requires_approval, pos_approval: nil, error: "requires approval") if @approver.blank?
      return denied("approver must differ from requester") if @approver.id == @requester&.id
      return denied("approver is not active") unless @approver.active? && !@approver.locked?
      return denied("approver credentials invalid") unless @approver.authenticate_pin(@approver_pin.to_s)
      return denied("approver lacks #{@approver_permission_key}") unless approver_permitted?

      authorization_limit_snapshot = nil

      if @limit_key
        approver_authority = Authorization::EvaluateAuthority.call(
          user: @approver, store: @store, limit_key: @limit_key, requested_value: @requested_value
        )
        return denied("approver authority is also insufficient") unless approver_authority.allow?

        authorization_limit_snapshot = approver_authority.configured_limit
      end

      approval = PosApproval.create!(
        store: @store,
        pos_session: @pos_session,
        pos_transaction: @pos_transaction,
        pos_line_item: @pos_line_item,
        action_type: @action_type,
        requested_by_user: @requester,
        approved_by_user: @approver,
        reason: @reason.presence || "approved",
        requested_value: @requested_value,
        approved_value: @requested_value,
        authorization_limit_snapshot: authorization_limit_snapshot,
        approved_at: Time.current
      )

      Result.new(status: :approved, pos_approval: approval, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      denied(e.message)
    end

    def requester_permitted?
      Authorization::EvaluatePermission.call(user: @requester, store: @store, permission_key: @permission_key) == :allow
    end

    def approver_permitted?
      Authorization::EvaluatePermission.call(
        user: @approver, store: @store, permission_key: @approver_permission_key
      ) == :allow
    end

    def allowed
      Result.new(status: :allowed, pos_approval: nil, error: nil)
    end

    def denied(error)
      Result.new(status: :denied, pos_approval: nil, error: error)
    end
  end
end
