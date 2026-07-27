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

        can_open = Authorization::EvaluatePermission.call(
          user: @actor, store: session.store, permission_key: "pos.transaction.open"
        ) == :allow
        opened = FindOrOpenActiveTransaction.call(
          pos_session: session,
          actor: @actor,
          create_if_missing: can_open
        )
        unless opened.success?
          next failure(
            can_open ? opened.error : "missing permission pos.transaction.open"
          )
        end
        transaction = opened.pos_transaction

        unless opened.created?
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
