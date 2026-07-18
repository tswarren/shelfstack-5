# frozen_string_literal: true

module Pos
  # Recall is exclusive: one register at a time. Row-level locking makes a
  # concurrent double recall of the same suspended transaction fail safely for
  # every caller after the first.
  class RecallTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error)

    def initialize(pos_transaction:, pos_session:, actor:)
      @pos_transaction = pos_transaction
      @pos_session = pos_session
      @actor = actor
    end

    def call
      raise Error, "session must be open" unless @pos_session.open?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "only suspended transactions may be recalled" unless transaction.suspended?
        raise Error, "transaction belongs to a different store" unless transaction.store_id == @pos_session.store_id

        transaction.update!(
          status: "open",
          active_pos_session: @pos_session,
          recalled_at: Time.current
        )

        Result.new(pos_transaction: transaction, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: nil, success?: false, error: e.message)
    end
  end
end
