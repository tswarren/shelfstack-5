# frozen_string_literal: true

module Pos
  # Removes Customer from an open editable transaction (commercially inert).
  class RemoveCustomer < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error)

    def initialize(pos_transaction:, actor:)
      @pos_transaction = pos_transaction
      @actor = actor
    end

    def call
      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not editable" unless transaction.editable?

        transaction.update!(customer: nil)
        Result.new(pos_transaction: transaction, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: @pos_transaction, success?: false, error: e.message)
    end
  end
end
