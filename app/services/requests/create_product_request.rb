# frozen_string_literal: true

module Requests
  # Records acquisition demand against an existing Product (ADR-0015,
  # docs/domains/product-requests.md). Creating a request never changes
  # `on_hand` or `on_order` — it is a demand fact only.
  class CreateProductRequest < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:product_request, :success?, :error)

    ATTRIBUTES = %w[
      request_type product_id product_variant_id requested_quantity priority
      needed_by_on customer_reference assigned_buyer_user_id notes supersedes_product_request_id
    ].freeze

    def initialize(store:, attributes:, actor:, requested_by_user: nil)
      @store = store
      @attributes = attributes.to_h.stringify_keys.slice(*ATTRIBUTES)
      @actor = actor
      @requested_by_user = requested_by_user || actor
    end

    def call
      raise Error, "not permitted to create product requests" unless authorized?

      ActiveRecord::Base.transaction do
        product_request = @store.product_requests.new(@attributes)
        product_request.status = "open"
        product_request.requested_by_user = @requested_by_user
        product_request.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "requests.product_request.created",
          subject: product_request,
          metadata: {
            "request_type" => product_request.request_type,
            "product_id" => product_request.product_id,
            "requested_quantity" => product_request.requested_quantity
          }
        )

        Result.new(product_request: product_request, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(product_request: e.record, success?: false, error: e.record.errors.full_messages.to_sentence)
    rescue Error => e
      Result.new(product_request: nil, success?: false, error: e.message)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "requests.product_request.create") == :allow
    end
  end
end
