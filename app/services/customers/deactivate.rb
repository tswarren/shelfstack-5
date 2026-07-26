# frozen_string_literal: true

module Customers
  class Deactivate < ApplicationService
    Result = Data.define(:customer, :success?, :error)

    def initialize(customer:, actor:, store: nil)
      @customer = customer
      @actor = actor
      @store = store
    end

    def call
      @customer.update!(active: false)

      if @store.present? && @actor.present?
        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @customer.organization,
          store: @store,
          action: "customers.customer.deactivated",
          subject: @customer,
          metadata: { "customer_number" => @customer.customer_number }
        )
      end

      Result.new(customer: @customer, success?: true, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(customer: e.record, success?: false, error: e.record.errors.full_messages.to_sentence)
    end
  end
end
