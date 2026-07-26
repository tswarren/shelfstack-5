# frozen_string_literal: true

module Pos
  class ClearStagedCustomer < ApplicationService
    Result = Data.define(:pos_session, :success?, :error)

    def initialize(pos_session:, actor: nil, force: false)
      @pos_session = pos_session
      @actor = actor
      @force = force
    end

    def call
      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)
        if session.staged_customer_id.blank?
          return Result.new(pos_session: session, success?: true, error: nil)
        end

        unless @force
          if @actor.nil? || session.staged_customer_by_user_id != @actor.id
            return Result.new(pos_session: session, success?: false, error: "only the staging cashier may clear this staged customer")
          end
        end

        session.update!(
          staged_customer: nil,
          staged_customer_by_user: nil,
          staged_customer_at: nil
        )
        Result.new(pos_session: session, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(pos_session: @pos_session, success?: false, error: e.message)
    end
  end
end
