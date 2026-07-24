# frozen_string_literal: true

module Pos
  # Shared authorization workflow for restricted POS actions. Separates permission,
  # numeric authority, and approval per ADR-0011:
  #
  # * the requester must hold `permission_key` to attempt the action at all —
  #   missing permission is a hard deny and cannot be bypassed by an approver;
  # * when `approval_mode: :always`, an approver must authenticate and a PosApproval
  #   is always recorded (create alone never silently passes);
  # * when `limit_key` is present (and approval_mode is not :always), the requester's
  #   numeric authority governs whether they may proceed directly or must escalate;
  # * when `limit_key` is absent and approval_mode is not :always, holding
  #   `permission_key` is itself sufficient;
  # * an approver must authenticate with their own credentials and hold
  #   `approver_permission_key` (defaults to `permission_key`);
  # * when approver == requester, `self_approver_permission_key` is required
  #   (defaults denied — self-approval is opt-in per action).
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
                    approval_mode: nil,
                    approver: nil, approver_pin: nil, approver_permission_key: nil,
                    self_approver_permission_key: nil,
                    pos_transaction: nil, pos_line_item: nil, pos_session: nil)
      @store = store
      @requester = requester
      @permission_key = permission_key.to_s
      @approver_permission_key = (approver_permission_key || permission_key).to_s
      @self_approver_permission_key = self_approver_permission_key&.to_s
      @action_type = action_type
      @reason = reason
      @limit_key = limit_key
      @requested_value = requested_value
      @approval_mode = approval_mode&.to_sym
      @approver = approver
      @approver_pin = approver_pin
      @pos_transaction = pos_transaction
      @pos_line_item = pos_line_item
      @pos_session = pos_session
    end

    def call
      unless requester_permitted?
        return denied("missing permission #{@permission_key}")
      end

      if @approval_mode == :always
        escalate_with_approver
      elsif @limit_key.nil?
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
      return denied("approver is not active") unless @approver.active? && !@approver.locked?
      return denied("approver credentials invalid") unless @approver.authenticate_pin(@approver_pin.to_s)

      if self_approval?
        if @self_approver_permission_key.blank?
          return denied("self-approval is not permitted for this action")
        end
        return denied("missing permission #{@self_approver_permission_key}") unless self_approver_permitted?
      else
        return denied("approver must differ from requester") if @approver.id == @requester&.id
        return denied("approver lacks #{@approver_permission_key}") unless approver_permitted?
      end

      authorization_limit_snapshot = nil

      if @limit_key && !self_approval?
        approver_authority = Authorization::EvaluateAuthority.call(
          user: @approver, store: @store, limit_key: @limit_key, requested_value: @requested_value
        )
        return denied("approver authority is also insufficient") unless approver_authority.allow?

        authorization_limit_snapshot = approver_authority.configured_limit
      elsif @limit_key && self_approval?
        # approve_self is the elevated exception: do not re-apply the same
        # membership threshold that forced escalation. Snapshot still recorded.
        self_authority = Authorization::EvaluateAuthority.call(
          user: @approver, store: @store, limit_key: @limit_key, requested_value: @requested_value
        )
        authorization_limit_snapshot = self_authority.configured_limit
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

    def self_approval?
      @approver.present? && @requester.present? && @approver.id == @requester.id
    end

    def requester_permitted?
      Authorization::EvaluatePermission.call(user: @requester, store: @store, permission_key: @permission_key) == :allow
    end

    def approver_permitted?
      Authorization::EvaluatePermission.call(
        user: @approver, store: @store, permission_key: @approver_permission_key
      ) == :allow
    end

    def self_approver_permitted?
      return false if @self_approver_permission_key.blank?

      Authorization::EvaluatePermission.call(
        user: @approver, store: @store, permission_key: @self_approver_permission_key
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
