# frozen_string_literal: true

module Requests
  # Commits physically confirmed on-hand inventory to a Customer Request
  # (`requests.customer_request.reserve`; docs/domains/product-requests.md
  # "Customer Request workflow" step 1). Requires an explicit
  # `physically_confirmed` acknowledgement — this service never reserves
  # merchandise the caller has not actually confirmed present on the shelf
  # (ADR-0006 "do not reserve merchandise that is not physically present").
  #
  # Uses `Inventory::Reserve` with `source_type: "product_request"`, adding
  # `quantity` on top of any existing active Reservation for the same request
  # and variant (one Customer Request carries at most one active in-house
  # Reservation row, aggregated across separate reserve calls, mirroring how
  # `Inventory::PostReceipt` accumulates converted allocation quantity onto
  # the same row).
  #
  # Quantity-tracked variants aggregate onto one active Reservation row.
  # Individually tracked variants require an exact Inventory Unit and reserve
  # quantity 1 per unit; a request may hold several unit reservation rows.
  class ReserveInHouseInventory < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:product_request, :reservation, :success?, :error)

    def initialize(product_request:, quantity:, actor:, store:, physically_confirmed: false, inventory_unit: nil)
      @product_request = product_request
      @quantity = quantity.to_i
      @actor = actor
      @store = store
      @physically_confirmed = physically_confirmed
      @inventory_unit = inventory_unit
    end

    def call
      raise Error, "not permitted to reserve for customer requests" unless authorized?
      raise Error, "product request is required" if @product_request.blank?
      raise Error, "quantity must be a positive integer" unless @quantity.positive?
      unless ActiveModel::Type::Boolean.new.cast(@physically_confirmed)
        raise Error, "physical confirmation is required before reserving in-house inventory"
      end

      ActiveRecord::Base.transaction do
        product_request = ProductRequest.lock.find(@product_request.id)
        raise Error, "reservation applies only to customer requests" unless product_request.customer_request?
        raise Error, "product request store mismatch" unless product_request.store_id == @store.id
        raise Error, "product request is not open" unless product_request.open?

        variant = product_request.product_variant
        raise Error, "product request has no resolved product variant to reserve" if variant.blank?

        uncovered = product_request.uncovered_quantity
        if @quantity > uncovered
          raise Error, "quantity exceeds the product request's uncovered quantity (#{uncovered} uncovered)"
        end

        reserve_result = case variant.inventory_tracking_mode
        when "quantity"
          raise Error, "inventory unit must not be given for quantity-tracked variants" if @inventory_unit.present?

          existing = InventoryReservation.active.lock.find_by(
            store_id: @store.id, product_variant_id: variant.id,
            source_type: "product_request", source_id: product_request.id
          )
          Inventory::Reserve.call(
            store: @store, product_variant: variant, quantity: (existing&.quantity || 0) + @quantity,
            source_type: "product_request", source_id: product_request.id, actor: @actor
          )
        when "individual"
          raise Error, "quantity must be 1 for individually tracked variants" unless @quantity == 1
          raise Error, "inventory unit is required for individually tracked variants" if @inventory_unit.blank?
          unless product_request.compatible_with_variant?(@inventory_unit.product_variant)
            raise Error, product_request.compatibility_error_for(@inventory_unit.product_variant)
          end

          Inventory::Reserve.call(
            store: @store, product_variant: variant, quantity: 1,
            source_type: "product_request", source_id: product_request.id,
            actor: @actor, inventory_unit: @inventory_unit
          )
        else
          raise Error, "in-house reservation requires a quantity- or individually tracked variant"
        end
        raise Error, reserve_result.error unless reserve_result.success?

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "requests.customer_request.reserved",
          subject: product_request,
          metadata: {
            "quantity" => @quantity,
            "inventory_reservation_id" => reserve_result.reservation.id,
            "inventory_unit_id" => @inventory_unit&.id
          }
        )

        Result.new(product_request: product_request, reservation: reserve_result.reservation, success?: true, error: nil)
      end
    rescue Error => e
      Result.new(product_request: @product_request, reservation: nil, success?: false, error: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(product_request: @product_request, reservation: nil, success?: false,
                 error: e.record.errors.full_messages.to_sentence)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "requests.customer_request.reserve") == :allow
    end
  end
end
