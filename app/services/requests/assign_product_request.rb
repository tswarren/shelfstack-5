# frozen_string_literal: true

module Requests
  # Assigns or reassigns the buyer responsible for deciding an open Product
  # Request (product-requests.md permissions).
  class AssignProductRequest < ApplicationService
    Result = Data.define(:product_request, :success?, :error)

    def initialize(product_request:, assigned_buyer_user:, actor:, store:)
      @product_request = product_request
      @assigned_buyer_user = assigned_buyer_user
      @actor = actor
      @store = store
    end

    def call
      return failure("not permitted to assign product requests") unless authorized?

      ActiveRecord::Base.transaction do
        @product_request.reload.lock!
        return failure("product request store mismatch") unless @product_request.store_id == @store.id
        return failure("only open requests can be assigned") unless @product_request.open?

        previous_buyer_id = @product_request.assigned_buyer_user_id
        @product_request.update!(assigned_buyer_user: @assigned_buyer_user)

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "requests.product_request.assigned",
          subject: @product_request,
          metadata: {
            "previous_assigned_buyer_user_id" => previous_buyer_id,
            "assigned_buyer_user_id" => @product_request.assigned_buyer_user_id
          }
        )

        Result.new(product_request: @product_request.reload, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "requests.product_request.assign") == :allow
    end

    def failure(message)
      Result.new(product_request: @product_request, success?: false, error: message)
    end
  end
end
