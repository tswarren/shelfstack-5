# frozen_string_literal: true

module Requests
  # Records the Product Request Fulfilment fact for a completed POS sale line
  # linked to a Customer Request (OD-007 "Product Request fulfilment"). Called
  # from inside `Pos::CompleteTransaction`'s own transaction, after the line's
  # sale inventory movement has already posted — never on its own.
  #
  # Under the Product Request lock, revalidates that the request remains open,
  # belongs to the POS store, remains product/variant-compatible with the sale
  # line, and that the fulfilment quantity does not exceed current outstanding
  # quantity. AddLine checks are not authoritative at completion.
  #
  # The Reservation for a tracked sale is converted by
  # `Inventory::ConvertReservation` before this service runs. Pass that
  # converted reservation so the fulfilment fact references it. Do not
  # independently release or reduce a residual `product_request` reservation —
  # POS handoff already moved coverage onto the POS line.
  #
  # Idempotent via unique `posting_key` (`pos_line_item:<id>:fulfillment`).
  class RecordFulfillment < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:product_request_fulfillment, :product_request, :success?, :error, :replayed)

    def initialize(product_request:, pos_line_item:, actor:, quantity: nil, fulfilled_at: nil, converted_reservation: nil)
      @product_request = product_request
      @pos_line_item = pos_line_item
      @actor = actor
      @quantity = (quantity || pos_line_item.quantity).to_i
      @fulfilled_at = fulfilled_at || Time.current
      @converted_reservation = converted_reservation
    end

    def call
      posting_key = self.class.posting_key(@pos_line_item)

      ActiveRecord::Base.transaction do
        existing = ProductRequestFulfillment.find_by(posting_key: posting_key)
        if existing
          return Result.new(product_request_fulfillment: existing, product_request: existing.product_request,
                             success?: true, error: nil, replayed: true)
        end

        raise Error, "not permitted to record customer-request fulfilment" unless authorized?
        raise Error, "quantity must be a positive integer" unless @quantity.positive?
        raise Error, "line does not reference this product request" unless @pos_line_item.product_request_id == @product_request.id

        product_request = ProductRequest.lock.find(@product_request.id)
        store = @pos_line_item.pos_transaction.store
        variant = @pos_line_item.product_variant

        raise Error, "fulfilment applies only to customer requests" unless product_request.customer_request?
        raise Error, "product request is not open" unless product_request.open?
        raise Error, "product request store mismatch" unless product_request.store_id == store.id
        unless product_request.compatible_with_variant?(variant)
          raise Error, product_request.compatibility_error_for(variant)
        end

        outstanding = product_request.outstanding_quantity
        if @quantity > outstanding
          raise Error, "quantity exceeds the product request's outstanding quantity (#{outstanding} outstanding)"
        end

        reservation = resolved_converted_reservation!

        fulfillment = ProductRequestFulfillment.create!(
          product_request: product_request,
          inventory_reservation: reservation,
          pos_line_item: @pos_line_item,
          quantity: @quantity,
          kind: "fulfill",
          fulfilled_at: @fulfilled_at,
          fulfilled_by_user: @actor,
          posting_key: posting_key
        )

        close_if_complete!(product_request)

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "requests.customer_request.fulfilled",
          subject: product_request,
          metadata: { "pos_line_item_id" => @pos_line_item.id, "quantity" => @quantity }
        )

        Result.new(product_request_fulfillment: fulfillment, product_request: product_request.reload,
                   success?: true, error: nil, replayed: false)
      end
    rescue Error => e
      Result.new(product_request_fulfillment: nil, product_request: @product_request, success?: false,
                 error: e.message, replayed: false)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(product_request_fulfillment: nil, product_request: @product_request, success?: false,
                 error: e.record.errors.full_messages.to_sentence, replayed: false)
    end

    def self.posting_key(pos_line_item)
      "pos_line_item:#{pos_line_item.id}:fulfillment"
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @pos_line_item.pos_transaction.store,
                                              permission_key: "requests.customer_request.fulfill") == :allow
    end

    def resolved_converted_reservation!
      return nil if @converted_reservation.blank?

      reservation = @converted_reservation
      unless reservation.status == "converted"
        raise Error, "fulfilment reservation must already be converted"
      end
      unless reservation.source_type == "pos_line_item" && reservation.source_id == @pos_line_item.id
        raise Error, "fulfilment reservation does not belong to this POS line"
      end

      reservation
    end

    def close_if_complete!(product_request)
      return unless product_request.open?
      return if product_request.fulfilled_quantity < product_request.requested_quantity

      product_request.update!(status: "fulfilled")
    end
  end
end
