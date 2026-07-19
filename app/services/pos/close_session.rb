# frozen_string_literal: true

module Pos
  class CloseSession < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_session, :success?, :error, :replayed)

    def initialize(pos_session:, actor:)
      @pos_session = pos_session
      @actor = actor
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
        # so the open-transaction guard above already enforces this invariant.
        if PosTransaction.where(active_pos_session_id: session.id, status: "open").exists?
          raise Error, "cannot close session while it controls an open transaction"
        end

        session.update!(status: "closed", closed_at: Time.current, closed_by_user: @actor)

        Result.new(pos_session: session, success?: true, error: nil, replayed: false)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_session: @pos_session, success?: false, error: e.message, replayed: false)
    end
  end
end
