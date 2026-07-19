# frozen_string_literal: true

module Pos
  # Records a closing counted-cash observation for a cash-enabled Session.
  # Prefer `Pos::CloseSession(counted_cash_cents:)` so the count and close commit
  # atomically after close guards pass. This service remains for callers that need
  # to persist a count independently; CloseSession will reuse it or append a
  # manager_recount when a different amount is supplied at close.
  class RecordClosingCashCount < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_session_cash_count, :success?, :error)

    def initialize(pos_session:, counted_cash_cents:, actor:)
      @pos_session = pos_session
      @counted_cash_cents = counted_cash_cents.to_i
      @actor = actor
    end

    def call
      raise Error, "counted cash must not be negative" if @counted_cash_cents.negative?
      raise Error, "session has no cash drawer" if @pos_session.cash_drawer_id.blank?

      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)
        raise Error, "session must be open" unless session.open?
        raise Error, "session has no cash drawer" if session.cash_drawer_id.blank?

        if PosSessionCashCount.exists?(pos_session_id: session.id, count_type: "closing")
          raise Error, "closing cash count already recorded"
        end

        count = PosSessionCashCount.create!(
          pos_session: session,
          count_type: "closing",
          total_cents: @counted_cash_cents,
          counted_by_user: @actor,
          counted_at: Time.current,
          created_at: Time.current
        )

        Result.new(pos_session_cash_count: count, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Result.new(pos_session_cash_count: nil, success?: false, error: e.message)
    end
  end
end
