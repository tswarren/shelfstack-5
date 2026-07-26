# frozen_string_literal: true

module Pos
  # Stages a Customer on the POS session for the acting cashier.
  # One staged customer per session (MVP); replace + warn when overwriting.
  class StageCustomer < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_session, :success?, :error, :replaced_prior)

    def initialize(pos_session:, customer:, actor:)
      @pos_session = pos_session
      @customer = customer
      @actor = actor
    end

    def call
      raise Error, "session must be open" unless @pos_session.open?
      raise Error, "customer not found" unless @customer
      raise Error, "customer belongs to another organization" unless @customer.organization_id == @pos_session.store.organization_id
      raise Error, "inactive customers cannot be staged" unless @customer.active?

      replaced = false
      ActiveRecord::Base.transaction do
        session = PosSession.lock.find(@pos_session.id)
        raise Error, "session must be open" unless session.open?

        replaced = session.staged_customer_id.present? &&
          (session.staged_customer_id != @customer.id || session.staged_customer_by_user_id != @actor.id)

        session.update!(
          staged_customer: @customer,
          staged_customer_by_user: @actor,
          staged_customer_at: Time.current
        )
        Result.new(pos_session: session, success?: true, error: nil, replaced_prior: replaced)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_session: @pos_session, success?: false, error: e.message, replaced_prior: false)
    end
  end
end
