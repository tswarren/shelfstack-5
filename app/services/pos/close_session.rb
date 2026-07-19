# frozen_string_literal: true

module Pos
  class CloseSession < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_session, :success?, :error, :replayed)

    def initialize(pos_session:, actor:, counted_cash_cents: nil)
      @pos_session = pos_session
      @actor = actor
      @counted_cash_cents = counted_cash_cents
    end

    def call
      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)

        if session.closed?
          return Result.new(pos_session: session, success?: true, error: nil, replayed: true)
        end

        # Session close blocked by unresolved Tenders: a Transaction holding a
        # pending/authorized Tender is always still `open` (Suspend itself is
        # blocked while unresolved Tenders exist — see Pos::SuspendTransaction),
        # so the open-transaction guard already enforces this invariant.
        if PosTransaction.where(active_pos_session_id: session.id, status: "open").exists?
          raise Error, "cannot close session while it controls an open transaction"
        end

        if session.cash_enabled?
          closing = resolve_closing_count!(session)
          expected = Pos::CalculateExpectedCash.call(pos_session: session).expected_cash_cents
          session.update!(
            status: "closed",
            closed_at: Time.current,
            closed_by_user: @actor,
            expected_cash_cents: expected,
            counted_cash_cents: closing.total_cents,
            cash_variance_cents: closing.total_cents - expected
          )
        else
          session.update!(status: "closed", closed_at: Time.current, closed_by_user: @actor)
        end

        Result.new(pos_session: session, success?: true, error: nil, replayed: false)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(pos_session: @pos_session, success?: false, error: e.message, replayed: false)
    end

    private

    def resolve_closing_count!(session)
      existing_closing = PosSessionCashCount.find_by(pos_session_id: session.id, count_type: "closing")
      latest = PosSessionCashCount
        .where(pos_session_id: session.id, count_type: %w[closing manager_recount])
        .order(:id)
        .last
      now = Time.current

      if @counted_cash_cents.nil?
        raise Error, "closing cash count is required before closing a cash-enabled session" if latest.blank?

        return latest
      end

      counted = @counted_cash_cents.to_i
      raise Error, "counted cash must not be negative" if counted.negative?

      if existing_closing.nil?
        PosSessionCashCount.create!(
          pos_session: session,
          count_type: "closing",
          total_cents: counted,
          counted_by_user: @actor,
          counted_at: now,
          created_at: now
        )
      elsif latest.total_cents != counted
        PosSessionCashCount.create!(
          pos_session: session,
          count_type: "manager_recount",
          total_cents: counted,
          counted_by_user: @actor,
          counted_at: now,
          created_at: now
        )
      else
        latest
      end
    end
  end
end
