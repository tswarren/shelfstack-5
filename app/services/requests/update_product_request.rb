# frozen_string_literal: true

module Requests
  # Edits a still-open Product Request. Product identity is not editable here —
  # changing the underlying Product is a new request (product-requests.md).
  #
  # Reducing `requested_quantity` below already-fulfilled quantity is rejected.
  # Reducing below active reservations + remaining allocations releases the
  # excess commitments with `request_quantity_reduced` so covered supply cannot
  # exceed the new requested quantity.
  class UpdateProductRequest < ApplicationService
    Error = Class.new(StandardError)
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
        previous_quantity = @product_request.requested_quantity
        @product_request.assign_attributes(@attributes)

        if @product_request.requested_quantity_changed?
          enforce_quantity_floor!
          release_excess_commitments!(previous_quantity) if @product_request.requested_quantity < previous_quantity
        end

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
    rescue Error, ArgumentError => e
      failure(e.message)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "requests.product_request.edit") == :allow
    end

    def enforce_quantity_floor!
      fulfilled = @product_request.fulfilled_quantity
      if @product_request.requested_quantity < fulfilled
        raise Error, "requested quantity cannot be less than already fulfilled quantity (#{fulfilled})"
      end
    end

    def release_excess_commitments!(previous_quantity)
      target = @product_request.requested_quantity
      excess = @product_request.covered_quantity - target
      return unless excess.positive?

      # Prefer releasing future supply (allocations) before physical reservations.
      excess = release_allocations!(excess)
      release_reservations!(excess) if excess.positive?
    end

    def release_allocations!(excess)
      PurchaseOrderAllocation.where(product_request_id: @product_request.id)
        .includes(:purchase_order_allocation_events)
        .sort_by(&:id)
        .reverse_each do |allocation|
          break unless excess.positive?

          locked = PurchaseOrderAllocation.lock.find(allocation.id)
          remaining = locked.remaining_quantity
          next unless remaining.positive?

          release_qty = [ remaining, excess ].min
          locked.release!(
            quantity: release_qty,
            reason: "request_quantity_reduced",
            actor: @actor,
            posting_key: "product_request:#{@product_request.id}:allocation:#{locked.id}:qty_reduced:#{release_qty}"
          )
          excess -= release_qty
        end
      excess
    end

    def release_reservations!(excess)
      InventoryReservation.active.where(source_type: "product_request", source_id: @product_request.id)
        .order(:id).reverse_each do |reservation|
          break unless excess.positive?

          locked = InventoryReservation.lock.find(reservation.id)
          next unless locked.status == "active"

          if locked.quantity <= excess
            result = Inventory::ReleaseReservation.call(
              reservation: locked, actor: @actor, release_reason: "request_quantity_reduced"
            )
            raise Error, result.error unless result.success?

            excess -= locked.quantity
          else
            variant = locked.product_variant
            result = Inventory::Reserve.call(
              store: @store, product_variant: variant, quantity: locked.quantity - excess,
              source_type: "product_request", source_id: @product_request.id, actor: @actor,
              inventory_unit: locked.inventory_unit
            )
            raise Error, result.error unless result.success?

            excess = 0
          end
        end
      excess
    end

    def failure(message)
      Result.new(product_request: @product_request, success?: false, error: message)
    end
  end
end
