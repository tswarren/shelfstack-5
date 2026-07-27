# frozen_string_literal: true

module Pos
  # Ready-state first valid work: open (or reuse) a transaction and add an
  # unlinked return line. Never leaves an empty open transaction on failure.
  class StartUnlinkedReturn < ApplicationService
    Result = Data.define(:success?, :pos_transaction, :pos_line_item, :error, :pos_approval)

    def initialize(pos_session:, actor:, **add_kwargs)
      @pos_session = pos_session
      @actor = actor
      @add_kwargs = add_kwargs
    end

    def call
      return failure("POS session is not open.") unless @pos_session.open?

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
              error: "Staged customer was not attached because this transaction already has a different customer.",
              pos_approval: nil
            )
          end
          transaction.reload
        end

        add = AddUnlinkedReturnLine.call(
          pos_transaction: transaction,
          actor: @actor,
          **@add_kwargs
        )
        unless add.success?
          add_error = add.error
          raise ActiveRecord::Rollback
        end

        Result.new(
          success?: true,
          pos_transaction: transaction,
          pos_line_item: add.pos_line_item,
          error: nil,
          pos_approval: add.pos_approval
        )
      end

      result || failure(add_error.presence || "Unable to start unlinked return.")
    end

    private

    def failure(message)
      Result.new(
        success?: false,
        pos_transaction: nil,
        pos_line_item: nil,
        error: message,
        pos_approval: nil
      )
    end
  end
end
