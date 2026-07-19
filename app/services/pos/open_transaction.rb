# frozen_string_literal: true

module Pos
  class OpenTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error)

    def initialize(pos_session:, actor:, cashier: nil)
      @pos_session = pos_session
      @actor = actor
      @cashier = cashier || pos_session.cashier_user
    end

    def call
      ActiveRecord::Base.transaction do
        # Lock parent Session and recheck status under the lock before creating
        # a child Transaction (prevents open-on-closed race with CloseSession).
        session = PosSession.lock.find(@pos_session.id)
        raise Error, "session must be open" unless session.open?

        transaction = PosTransaction.create!(
          store: session.store,
          origin_pos_session: session,
          active_pos_session: session,
          cashier_user: @cashier,
          status: "open",
          opened_at: Time.current
        )

        Result.new(pos_transaction: transaction, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: nil, success?: false, error: e.message)
    end
  end
end
