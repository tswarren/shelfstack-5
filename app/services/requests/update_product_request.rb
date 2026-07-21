# frozen_string_literal: true

module Requests
  # Edits a still-open Product Request. Product identity is not editable here —
  # changing the underlying Product is a new request (product-requests.md).
  class UpdateProductRequest < ApplicationService
    Result = Data.define(:product_request, :success?, :error)

    ATTRIBUTES = %w[
      product_variant_id requested_quantity priority needed_by_on customer_reference notes
    ].freeze

    def initialize(product_request:, attributes:, actor:, store:)
      @product_request = product_request
      @attributes = attributes.to_h.stringify_keys.slice(*ATTRIBUTES)
      @actor = actor
      @store = store
    end

    def call
      return failure("not permitted to edit product requests") unless authorized?

      ActiveRecord::Base.transaction do
        @product_request.reload.lock!
        return failure("product request store mismatch") unless @product_request.store_id == @store.id
        return failure("only open requests can be edited") unless @product_request.open?

        before = Administration::ChangeMetadata.snapshot(@product_request, ATTRIBUTES)
        @product_request.assign_attributes(@attributes)
        @product_request.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "requests.product_request.updated",
          subject: @product_request,
          metadata: {
            "before" => before,
            "after" => Administration::ChangeMetadata.snapshot(@product_request, ATTRIBUTES)
          }
        )

        Result.new(product_request: @product_request.reload, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "requests.product_request.edit") == :allow
    end

    def failure(message)
      Result.new(product_request: @product_request, success?: false, error: message)
    end
  end
end
