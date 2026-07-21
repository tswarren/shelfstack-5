# frozen_string_literal: true

module Purchasing
  # Commits open `ordered` Purchase-Order Line quantity to a Customer Request
  # (ADR-0015 §6; OD-007). Never touches On Hand or Reserved; the allocation
  # is a claim on expected future supply only. Caps the requested quantity
  # against both:
  #
  #   * the Purchase-Order Line's open (unallocated) quantity — never claim
  #     more expected supply than the line can still deliver; and
  #   * the Customer Request's uncovered quantity — requested minus fulfilled
  #     quantity minus already confirmed physical Inventory Reservations
  #     minus already remaining allocated quantity (OD-007; `ProductRequest#uncovered_quantity`).
  #
  # Locks the Purchase-Order Line then the Product Request (in that order)
  # so concurrent allocation attempts against the same line or the same
  # request are serialized rather than racing past either cap.
  class CreateAllocation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:purchase_order_allocation, :success?, :error)

    def initialize(purchase_order_line:, product_request:, quantity:, actor:, store:)
      @purchase_order_line = purchase_order_line
      @product_request = product_request
      @quantity = quantity.to_i
      @actor = actor
      @store = store
    end

    def call
      raise Error, "not permitted to create purchase-order allocations" unless authorized?
      raise Error, "purchase order line is required" if @purchase_order_line.blank?
      raise Error, "product request is required" if @product_request.blank?
      raise Error, "quantity must be a positive integer" unless @quantity.positive?

      ActiveRecord::Base.transaction do
        line = PurchaseOrderLine.lock.find(@purchase_order_line.id)
        product_request = ProductRequest.lock.find(@product_request.id)
        purchase_order = line.purchase_order

        raise Error, "purchase-order allocations apply only to customer requests" unless product_request.customer_request?
        raise Error, "product request is not open" unless product_request.open?
        raise Error, "purchase order line store mismatch" unless purchase_order.store_id == @store.id
        raise Error, "product request store mismatch" unless product_request.store_id == @store.id
        raise Error, "only ordered purchase orders can allocate quantity" unless purchase_order.ordered?
        unless product_request.compatible_with_variant?(line.product_variant)
          raise Error, product_request.compatibility_error_for(line.product_variant)
        end
        if PurchaseOrderAllocation.exists?(purchase_order_line_id: line.id, product_request_id: product_request.id)
          raise Error, "an allocation already exists for this purchase-order line and product request"
        end

        available_on_line = line.open_quantity - remaining_allocated(purchase_order_line_id: line.id)
        if @quantity > available_on_line
          raise Error, "quantity exceeds open (unallocated) quantity on the purchase-order line (#{available_on_line} available)"
        end

        uncovered = product_request.uncovered_quantity
        if @quantity > uncovered
          raise Error, "quantity exceeds the product request's uncovered quantity (#{uncovered} uncovered)"
        end

        allocation = PurchaseOrderAllocation.create!(
          purchase_order_line: line,
          product_request: product_request,
          quantity: @quantity,
          created_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "purchasing.allocation.created",
          subject: allocation,
          metadata: {
            "purchase_order_line_id" => line.id,
            "product_request_id" => product_request.id,
            "quantity" => @quantity
          }
        )

        Result.new(purchase_order_allocation: allocation, success?: true, error: nil)
      end
    rescue Error => e
      Result.new(purchase_order_allocation: nil, success?: false, error: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(purchase_order_allocation: nil, success?: false, error: e.record.errors.full_messages.to_sentence)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "purchasing.allocation.create") == :allow
    end

    def remaining_allocated(scope_attrs)
      PurchaseOrderAllocation.where(scope_attrs).includes(:purchase_order_allocation_events).sum(&:remaining_quantity)
    end
  end
end
