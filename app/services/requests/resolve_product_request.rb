# frozen_string_literal: true

module Requests
  # Records a buyer's terminal decision for a non-customer Product Request
  # (staff_suggestion, stock_replenishment, frontlist_selection).
  #
  # Customer Requests remain open fulfilment obligations resolved through
  # Purchase-Order Allocation / Inventory Reservation / Product Request
  # Fulfilment (deferred to a later phase) — this service refuses them.
  #
  # `deferred` records the decision but leaves the request open
  # (product-requests.md). Every other resolution closes or declines the
  # request. When the buyer orders less than requested, pass
  # `resolved_quantity` for the ordered amount and, optionally,
  # `create_follow_up: true` to open a new request for the residual quantity,
  # linked back via `supersedes_product_request_id`
  # (phase-05-supply-and-demand.md planning defaults).
  class ResolveProductRequest < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:product_request, :follow_up_product_request, :success?, :error)

    CLOSING_RESOLUTIONS = %w[ordered duplicate superseded no_longer_needed].freeze

    def initialize(product_request:, resolution:, actor:, store:, resolved_quantity: nil, resolution_note: nil,
                    create_follow_up: false, follow_up_quantity: nil)
      @product_request = product_request
      @resolution = resolution.to_s
      @actor = actor
      @store = store
      @resolved_quantity = resolved_quantity
      @resolution_note = resolution_note
      @create_follow_up = ActiveModel::Type::Boolean.new.cast(create_follow_up)
      @follow_up_quantity = follow_up_quantity
    end

    def call
      raise Error, "not permitted to resolve product requests" unless authorized?
      raise Error, "resolution must be one of #{ProductRequest::RESOLUTIONS.join(', ')}" unless ProductRequest::RESOLUTIONS.include?(@resolution)

      ActiveRecord::Base.transaction do
        @product_request.reload.lock!
        raise Error, "product request store mismatch" unless @product_request.store_id == @store.id
        raise Error, "customer requests are resolved through fulfilment, not buyer resolution" if @product_request.customer_request?
        raise Error, "only open requests can be resolved" unless @product_request.open?

        resolved_quantity = resolved_quantity_for_resolution
        apply_resolution!(resolved_quantity)

        follow_up = maybe_create_follow_up!(resolved_quantity)

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "requests.product_request.resolved",
          subject: @product_request,
          metadata: {
            "resolution" => @resolution,
            "resolved_quantity" => resolved_quantity,
            "resolution_note" => @resolution_note,
            "follow_up_product_request_id" => follow_up&.id
          }
        )

        Result.new(product_request: @product_request.reload, follow_up_product_request: follow_up, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(product_request: @product_request, follow_up_product_request: nil, success?: false,
                 error: e.record.errors.full_messages.to_sentence)
    rescue Error => e
      Result.new(product_request: @product_request, follow_up_product_request: nil, success?: false, error: e.message)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "requests.product_request.resolve") == :allow
    end

    def resolved_quantity_for_resolution
      return @product_request.requested_quantity if @resolution == "ordered" && @resolved_quantity.nil?

      @resolved_quantity
    end

    def apply_resolution!(resolved_quantity)
      new_status = @resolution == "deferred" ? "open" : resolution_status

      @product_request.update!(
        status: new_status,
        resolution: @resolution,
        resolved_quantity: resolved_quantity,
        resolved_at: Time.current,
        resolved_by_user: @actor,
        resolution_note: @resolution_note
      )
    end

    def resolution_status
      case @resolution
      when "declined" then "declined"
      when *CLOSING_RESOLUTIONS then "closed"
      else
        raise Error, "unsupported resolution: #{@resolution}"
      end
    end

    def maybe_create_follow_up!(resolved_quantity)
      return nil unless @create_follow_up
      return nil unless @resolution == "ordered"

      residual = @follow_up_quantity.presence || (@product_request.requested_quantity - resolved_quantity.to_i)
      residual = residual.to_i
      return nil unless residual.positive?

      result = Requests::CreateProductRequest.call(
        store: @store,
        actor: @actor,
        requested_by_user: @product_request.requested_by_user,
        attributes: {
          request_type: @product_request.request_type,
          product_id: @product_request.product_id,
          product_variant_id: @product_request.product_variant_id,
          requested_quantity: residual,
          priority: @product_request.priority,
          needed_by_on: @product_request.needed_by_on,
          notes: @product_request.notes,
          supersedes_product_request_id: @product_request.id
        }
      )
      raise Error, "could not create follow-up request: #{result.error}" unless result.success?

      result.product_request
    end
  end
end
