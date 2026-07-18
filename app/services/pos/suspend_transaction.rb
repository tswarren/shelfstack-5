# frozen_string_literal: true

module Pos
  # Suspension retains Inventory Reservations and clears active-session control so
  # any register may later recall it (one at a time).
  class SuspendTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error)

    def initialize(pos_transaction:, actor:)
      @pos_transaction = pos_transaction
      @actor = actor
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "only open transactions may be suspended" unless transaction.open?

        transaction.update!(
          status: "suspended",
          suspended_at: Time.current,
          active_pos_session: nil
        )

        Result.new(pos_transaction: transaction, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: nil, success?: false, error: e.message)
    end
  end
end
