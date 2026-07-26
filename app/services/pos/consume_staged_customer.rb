# frozen_string_literal: true

module Pos
  # Attaches the session's staged customer to a transaction when the actor
  # owns the stage, then clears the triad atomically.
  class ConsumeStagedCustomer < ApplicationService
    Result = Data.define(:pos_transaction, :success?, :error, :consumed, :conflict?)

    def initialize(pos_session:, pos_transaction:, actor:)
      @pos_session = pos_session
      @pos_transaction = pos_transaction
      @actor = actor
    end

    def call
      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)
        if session.staged_customer_id.blank?
          return ok(consumed: false)
        end

        unless session.staged_customer_by_user_id == @actor.id
          return ok(consumed: false)
        end

        customer = Customer.find_by(id: session.staged_customer_id)
        unless customer&.active? && customer.organization_id == session.store.organization_id
          session.update!(staged_customer: nil, staged_customer_by_user: nil, staged_customer_at: nil)
          return ok(consumed: false)
        end

        transaction = PosTransaction.lock.find(@pos_transaction.id)

        if transaction.customer_id.present?
          if transaction.customer_id == customer.id
            clear_stage!(session)
            return Result.new(
              pos_transaction: transaction,
              success?: true,
              error: nil,
              consumed: true,
              conflict?: false
            )
          end

          return Result.new(
            pos_transaction: transaction,
            success?: true,
            error: "staged customer conflicts with transaction customer",
            consumed: false,
            conflict?: true
          )
        end

        transaction.update!(customer: customer)
        clear_stage!(session)

        Result.new(
          pos_transaction: transaction,
          success?: true,
          error: nil,
          consumed: true,
          conflict?: false
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(
        pos_transaction: @pos_transaction,
        success?: false,
        error: e.message,
        consumed: false,
        conflict?: false
      )
    end

    private

    def ok(consumed:)
      Result.new(
        pos_transaction: @pos_transaction,
        success?: true,
        error: nil,
        consumed: consumed,
        conflict?: false
      )
    end

    def clear_stage!(session)
      session.update!(staged_customer: nil, staged_customer_by_user: nil, staged_customer_at: nil)
    end
  end
end
