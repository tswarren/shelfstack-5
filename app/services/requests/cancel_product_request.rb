# frozen_string_literal: true

module Requests
  # Withdraws an open Product Request outright (e.g. duplicate entry, customer
  # withdrew). Distinct from Requests::ResolveProductRequest, which records a
  # buyer's terminal decision with a resolution code. Idempotent — replaying an
  # already-cancelled request is a no-op success.
  class CancelProductRequest < ApplicationService
    Result = Data.define(:product_request, :success?, :error, :replayed)

    def initialize(product_request:, actor:, store:, cancellation_reason: nil)
      @product_request = product_request
      @actor = actor
      @store = store
      @cancellation_reason = cancellation_reason
    end

    def call
      return failure("not permitted to cancel product requests") unless authorized?

      ActiveRecord::Base.transaction do
        @product_request.reload.lock!
        return failure("product request store mismatch") unless @product_request.store_id == @store.id

        if @product_request.cancelled?
          return Result.new(product_request: @product_request, success?: true, error: nil, replayed: true)
        end

        return failure("only open requests can be cancelled") unless @product_request.open?

        @product_request.update!(
          status: "cancelled",
          resolved_at: Time.current,
          resolved_by_user: @actor,
          resolution_note: @cancellation_reason
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "requests.product_request.cancelled",
          subject: @product_request,
          metadata: { "cancellation_reason" => @cancellation_reason }
        )

        Result.new(product_request: @product_request.reload, success?: true, error: nil, replayed: false)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "requests.product_request.cancel") == :allow
    end

    def failure(message)
      Result.new(product_request: @product_request, success?: false, error: message, replayed: false)
    end
  end
end
