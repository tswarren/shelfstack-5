# frozen_string_literal: true

module Pos
  # Attaches or replaces a Customer on an open editable transaction.
  # Phase 9: commercially inert — no price/tax/tender recalculation.
  class AttachCustomer < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error)

    def initialize(pos_transaction:, customer:, actor:)
      @pos_transaction = pos_transaction
      @customer = customer
      @actor = actor
    end

    def call
      raise Error, "customer not found" unless @customer
      raise Error, "customer belongs to another organization" unless @customer.organization_id == @pos_transaction.store.organization_id
      raise Error, "inactive customers cannot be attached" unless @customer.active?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not editable" unless transaction.editable?

        transaction.update!(customer: @customer)
        Result.new(pos_transaction: transaction, success?: true, error: nil)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: @pos_transaction, success?: false, error: e.message)
    end
  end
end
