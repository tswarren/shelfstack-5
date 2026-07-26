# frozen_string_literal: true

module Pos
  # Attaches the session's staged customer to a transaction when the actor
  # owns the stage, then clears the triad atomically.
  class ConsumeStagedCustomer < ApplicationService
    Result = Data.define(:pos_transaction, :success?, :error, :consumed)

    def initialize(pos_session:, pos_transaction:, actor:)
      @pos_session = pos_session
      @pos_transaction = pos_transaction
      @actor = actor
    end

    def call
      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)
        if session.staged_customer_id.blank?
          return Result.new(pos_transaction: @pos_transaction, success?: true, error: nil, consumed: false)
        end

        unless session.staged_customer_by_user_id == @actor.id
          return Result.new(pos_transaction: @pos_transaction, success?: true, error: nil, consumed: false)
        end

        customer = Customer.find_by(id: session.staged_customer_id)
        unless customer&.active? && customer.organization_id == session.store.organization_id
          session.update!(staged_customer: nil, staged_customer_by_user: nil, staged_customer_at: nil)
          return Result.new(pos_transaction: @pos_transaction, success?: true, error: nil, consumed: false)
        end

        transaction = PosTransaction.lock.find(@pos_transaction.id)
        transaction.update!(customer: customer) if transaction.customer_id.blank?
        session.update!(staged_customer: nil, staged_customer_by_user: nil, staged_customer_at: nil)

        Result.new(pos_transaction: transaction, success?: true, error: nil, consumed: true)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: @pos_transaction, success?: false, error: e.message, consumed: false)
    end
  end
end
