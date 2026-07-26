# frozen_string_literal: true

module Pos
  # Ready-state first valid work: open (or reuse) a transaction and add a gift-card line.
  # Never leaves an empty open transaction on failure.
  class StartStoredValue < ApplicationService
    Result = Data.define(:success?, :pos_transaction, :pos_line_item, :error)

    def initialize(pos_session:, actor:, account:, operation:, amount_cents:)
      @pos_session = pos_session
      @actor = actor
      @account = account
      @operation = operation
      @amount_cents = amount_cents
    end

    def call
      return failure("POS session is not open.") unless @pos_session.open?
      return failure("Select or create a gift-card account.") if @account.blank?

      add_error = nil
      result = ActiveRecord::Base.transaction(requires_new: true) do
        session = PosSession.lock.find(@pos_session.id)
        unless session.open?
          next failure("POS session is not open.")
        end

        transaction = PosTransaction.open_transactions.find_by(active_pos_session_id: session.id)
        unless transaction
          open = OpenTransaction.call(pos_session: session, actor: @actor)
          unless open.success?
            next failure(open.error)
          end
          transaction = open.pos_transaction
        else
          consume = ConsumeStagedCustomer.call(
            pos_session: session, pos_transaction: transaction, actor: @actor
          )
          if consume.conflict?
            next Result.new(
              success?: false,
              pos_transaction: transaction,
              pos_line_item: nil,
              error: "Staged customer was not attached because this transaction already has a different customer."
            )
          end
          transaction.reload
        end

        add = AddStoredValueLine.call(
          pos_transaction: transaction,
          account: @account,
          operation: @operation,
          amount_cents: @amount_cents,
          actor: @actor
        )
        unless add.success?
          add_error = add.error
          raise ActiveRecord::Rollback
        end

        Result.new(success?: true, pos_transaction: transaction, pos_line_item: add.pos_line_item, error: nil)
      end

      result || failure(add_error.presence || "Unable to start stored-value work.")
    end

    private

    def failure(message)
      Result.new(success?: false, pos_transaction: nil, pos_line_item: nil, error: message)
    end
  end
end
