# frozen_string_literal: true

module Pos
  # OD-P11-03: decide whether the cashier may leave Register for Operations
  # or Store Workspace while an open transaction exists.
  class LeaveRegisterGuard
    Result = Data.define(:status, :pos_transaction, :message)
    # status: :allow | :interrupt | :block

    def self.evaluate(user:, store:)
      new(user:, store:).evaluate
    end

    def initialize(user:, store:)
      @user = user
      @store = store
    end

    def evaluate
      txn = CurrentOpenTransaction.for(user: @user, store_id: @store&.id)
      return allow if txn.blank?

      if txn.void_required_tenders?
        return block(
          txn,
          "Resolve Recovery (card void required) before leaving Register."
        )
      end

      if txn.unresolved_tenders?
        return block(
          txn,
          "Clear or settle unresolved tenders before leaving Register."
        )
      end

      Result.new(
        status: :interrupt,
        pos_transaction: txn,
        message: "A transaction is still open. Suspend, cancel, or return to Register."
      )
    end

    private

    def allow
      Result.new(status: :allow, pos_transaction: nil, message: nil)
    end

    def block(txn, message)
      Result.new(status: :block, pos_transaction: txn, message: message)
    end
  end
end
