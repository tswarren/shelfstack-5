# frozen_string_literal: true

module Pos
  # Records an audited No Sale event for an open cash-enabled session.
  # Does not create a cash movement and does not kick a drawer.
  class RecordNoSale < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_no_sale_event, :success?, :error, :replayed)

    def initialize(pos_session:, actor:, reason:, idempotency_key:, occurred_at: nil)
      @pos_session = pos_session
      @actor = actor
      @reason = reason.to_s.strip
      @idempotency_key = idempotency_key.to_s.strip
      @occurred_at = occurred_at || Time.current
    end

    def call
      raise Error, "idempotency key is required" if @idempotency_key.blank?
      raise Error, "reason is required" if @reason.blank?
      raise Error, "reason is too long" if @reason.length > PosNoSaleEvent::REASON_MAX

      store = @pos_session.store
      unless Authorization::EvaluatePermission.call(
        user: @actor, store: store, permission_key: "pos.no_sale.create"
      ) == :allow
        raise Error, "missing permission pos.no_sale.create"
      end

      existing = PosNoSaleEvent.find_by(idempotency_key: @idempotency_key)
      if existing
        return Result.new(pos_no_sale_event: existing, success?: true, error: nil, replayed: true)
      end

      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)
        raise Error, "POS session is not open" unless session.open?
        raise Error, "No Sale requires a cash-enabled session" unless session.cash_enabled?

        event = PosNoSaleEvent.create!(
          organization: store.organization,
          store: store,
          pos_session: session,
          created_by_user: @actor,
          reason: @reason,
          occurred_at: @occurred_at,
          idempotency_key: @idempotency_key
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "pos.no_sale.recorded",
          subject: event,
          metadata: {
            "pos_session_id" => session.id,
            "reason" => @reason,
            "idempotency_key" => @idempotency_key
          }
        )

        Result.new(pos_no_sale_event: event, success?: true, error: nil, replayed: false)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_no_sale_event: nil, success?: false, error: e.message, replayed: false)
    rescue ActiveRecord::RecordNotUnique
      existing = PosNoSaleEvent.find_by!(idempotency_key: @idempotency_key)
      Result.new(pos_no_sale_event: existing, success?: true, error: nil, replayed: true)
    end
  end
end
