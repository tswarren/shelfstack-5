# frozen_string_literal: true

module Pos
  # Under the POS session row lock, reuse the session's open transaction or
  # create one. Callers decide whether creation is allowed (permission gate).
  class FindOrOpenActiveTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :created?, :success?, :error)

    def initialize(pos_session:, actor:, create_if_missing: false)
      @pos_session = pos_session
      @actor = actor
      @create_if_missing = create_if_missing
    end

    def call
      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)
        raise Error, "session must be open" unless session.open?

        existing = PosTransaction.open_transactions.find_by(active_pos_session_id: session.id)
        if existing
          return Result.new(pos_transaction: existing, created?: false, success?: true, error: nil)
        end

        unless @create_if_missing
          raise Error, "no open transaction on this session"
        end

        opened = OpenTransaction.call(pos_session: session, actor: @actor)
        raise Error, opened.error unless opened.success?

        Result.new(
          pos_transaction: opened.pos_transaction,
          created?: true,
          success?: true,
          error: nil
        )
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: nil, created?: false, success?: false, error: e.message)
    end
  end
end
