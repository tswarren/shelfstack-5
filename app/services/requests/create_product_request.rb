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
      needed_by_on customer_id assigned_buyer_user_id notes supersedes_product_request_id
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
        validate_customer_assignment!

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
            "requested_quantity" => product_request.requested_quantity,
            "customer_id" => product_request.customer_id
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

    def validate_customer_assignment!
      request_type = @attributes["request_type"].to_s
      customer_id = @attributes["customer_id"].presence

      if customer_id.present?
        raise Error, "not permitted to assign customers" unless can_lookup_customers?
      elsif request_type == "customer_request"
        raise Error, "customer is required for customer requests"
      else
        return
      end

      customer = Customer.find_by(id: customer_id)
      raise Error, "customer not found" unless customer
      raise Error, "customer belongs to another organization" unless customer.organization_id == @store.organization_id
      raise Error, "inactive customers cannot be assigned to new requests" unless customer.active?

      if request_type == "customer_request"
        unless Customers::Contactable.call(customer: customer)
          raise Error, "customer must be contactable (preferred phone or email with a primary contact value)"
        end
      end
    end

    def can_lookup_customers?
      Customers::AuthorizeLookup.call(user: @actor, store: @store)
    end
  end
end
