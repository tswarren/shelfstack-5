# frozen_string_literal: true

module Pos
  # Ready-state first valid work: open (or reuse) a transaction and add a gift-card line.
  # Never leaves an empty open transaction on failure.
  # When create_account is requested, account creation commits only with a successful line.
  class StartStoredValue < ApplicationService
    Result = Data.define(:success?, :pos_transaction, :pos_line_item, :error)

    def initialize(pos_session:, actor:, operation:, amount_cents:, account: nil,
                   create_account: false, organization: nil, store: nil, alternate_identifier: nil)
      @pos_session = pos_session
      @actor = actor
      @account = account
      @operation = operation
      @amount_cents = amount_cents
      @create_account = create_account
      @organization = organization
      @store = store
      @alternate_identifier = alternate_identifier
    end

    def call
      return failure("POS session is not open.") unless @pos_session.open?
      if !@create_account && @account.blank?
        return failure("Select or create a gift-card account.")
      end
      if @create_account && @organization.blank?
        return failure("Organization is required to create a gift-card account.")
      end

      rollback_error = nil
      result = ActiveRecord::Base.transaction(requires_new: true) do
        session = PosSession.lock.find(@pos_session.id)
        unless session.open?
          next failure("POS session is not open.")
        end

        account = @account
        if @create_account
          created = StoredValue::CreateAccount.call(
            organization: @organization,
            account_type: "gift_card",
            actor: @actor,
            store: @store,
            alternate_identifier: @alternate_identifier
          )
          unless created.success?
            rollback_error = created.error
            raise ActiveRecord::Rollback
          end
          account = created.account
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
          account: account,
          operation: @operation,
          amount_cents: @amount_cents,
          actor: @actor
        )
        unless add.success?
          rollback_error = add.error
          raise ActiveRecord::Rollback
        end

        Result.new(success?: true, pos_transaction: transaction, pos_line_item: add.pos_line_item, error: nil)
      end

      result || failure(rollback_error.presence || "Unable to start stored-value work.")
    end

    private

    def failure(message)
      Result.new(success?: false, pos_transaction: nil, pos_line_item: nil, error: message)
    end
  end
end
