# frozen_string_literal: true

module Pos
  # Adds a gift-card issue or reload sale line (no department, tax, or inventory).
  class AddStoredValueLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_transaction:, account:, operation:, amount_cents:, actor:)
      @pos_transaction = pos_transaction
      @account = account
      @operation = operation.to_s
      @amount_cents = amount_cents.to_i
      @actor = actor
    end

    def call
      raise Error, "transaction is not open for editing" unless @pos_transaction.editable?
      raise Error, "amount must be positive" unless @amount_cents.positive?
      raise Error, "operation must be issue or reload" unless %w[issue reload].include?(@operation)
      raise Error, "account organization mismatch" unless @account.organization_id == @pos_transaction.store.organization_id
      raise Error, "account is suspended" if @account.suspended?
      raise Error, "only gift cards may be issued or reloaded through POS" unless @account.account_type == "gift_card"

      permission = @operation == "issue" ? "stored_value.issue" : "stored_value.reload"
      unless Authorization::EvaluatePermission.call(
        user: @actor, store: @pos_transaction.store, permission_key: permission
      ) == :allow
        raise Error, "missing permission #{permission}"
      end

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open for editing" unless transaction.editable?
        account = StoredValueAccount.lock.find(@account.id)
        raise Error, "account is suspended" if account.suspended?
        raise Error, "only gift cards may be issued or reloaded through POS" unless account.account_type == "gift_card"
        if @operation == "issue" && StoredValueEntry.exists?(stored_value_account_id: account.id, entry_type: "issued")
          raise Error, "gift card already issued"
        end
        if @operation == "reload" && !StoredValueEntry.exists?(stored_value_account_id: account.id, entry_type: "issued")
          raise Error, "reload requires a prior issuance"
        end

        line = PosLineItem.create!(
          pos_transaction: transaction,
          line_kind: "stored_value",
          direction: "sale",
          status: "pending",
          quantity: 1,
          unit_price_cents: @amount_cents,
          department: nil,
          tax_category: nil,
          product_variant: nil,
          stored_value_account: account,
          stored_value_operation: @operation,
          stored_value_account_type_snapshot: account.account_type,
          stored_value_account_number_snapshot: account.account_number,
          description_snapshot: "#{@operation.titleize} gift card #{account.account_number}",
          position: next_position(transaction),
          created_by_user: @actor
        )

        recalculation = RecalculateTransaction.call(pos_transaction: transaction)
        Result.new(
          pos_line_item: line, success?: true, error: nil,
          warnings: (recalculation.blockers + recalculation.warnings).uniq
        )
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def next_position(transaction)
      (transaction.pos_line_items.maximum(:position) || 0) + 1
    end
  end
end
