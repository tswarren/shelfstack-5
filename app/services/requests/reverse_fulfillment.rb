# frozen_string_literal: true

module Requests
  # Undoes previously recorded Customer Request fulfilment when a linked POS
  # return (or, later, a post-void) reverses a completed sale line that had
  # fulfilled a request. Never edits or deletes the original `fulfill`
  # ProductRequestFulfillment (ADR-0008 "completed activity is immutable");
  # appends a `reverse` row referencing it via `linked_fulfillment_id` instead.
  #
  # A no-op success (no row created) when the original sale line was never
  # linked to a Product Request, or when its fulfilled quantity has already
  # been fully reversed by prior linked returns — callers do not need to
  # check this themselves.
  #
  # Idempotent via unique `posting_key` (`pos_line_item:<return line id>:fulfillment_reverse`).
  # If the reversal brings a `fulfilled` request's fulfilled quantity back
  # below its requested quantity, the request reopens (`status: "open"`) —
  # it remains a continuing obligation, per domain "Customer Requests remain
  # open as fulfilment obligations".
  #
  # Lock order: Product Request → Fulfilment (callers that already hold the
  # Product Request lock may pass `product_request:` to skip re-locking).
  class ReverseFulfillment < ApplicationService
    Result = Data.define(:product_request_fulfillment, :success?, :error, :replayed)

    def initialize(original_pos_line_item:, return_pos_line_item:, actor:, reversed_at: nil, product_request: nil)
      @original = original_pos_line_item
      @return_line = return_pos_line_item
      @actor = actor
      @reversed_at = reversed_at || Time.current
      @product_request = product_request
    end

    def call
      posting_key = self.class.posting_key(@return_line)

      ActiveRecord::Base.transaction do
        existing = ProductRequestFulfillment.find_by(posting_key: posting_key)
        if existing
          return Result.new(product_request_fulfillment: existing, success?: true, error: nil, replayed: true)
        end

        fulfill_preview = ProductRequestFulfillment.find_by(pos_line_item_id: @original.id, kind: "fulfill")
        if fulfill_preview.blank?
          return Result.new(product_request_fulfillment: nil, success?: true, error: nil, replayed: false)
        end

        product_request = @product_request || ProductRequest.lock.find(fulfill_preview.product_request_id)
        fulfillment = ProductRequestFulfillment.lock.find_by(pos_line_item_id: @original.id, kind: "fulfill")
        if fulfillment.blank?
          return Result.new(product_request_fulfillment: nil, success?: true, error: nil, replayed: false)
        end

        already_reversed = fulfillment.reversals.sum(:quantity)
        remaining = fulfillment.quantity - already_reversed
        reverse_quantity = [ @return_line.quantity, remaining ].min
        if reverse_quantity <= 0
          return Result.new(product_request_fulfillment: nil, success?: true, error: nil, replayed: false)
        end

        reversal = ProductRequestFulfillment.create!(
          product_request: product_request,
          pos_line_item: @return_line,
          quantity: reverse_quantity,
          kind: "reverse",
          linked_fulfilment: fulfillment,
          fulfilled_at: @reversed_at,
          fulfilled_by_user: @actor,
          posting_key: posting_key
        )

        reopen_if_needed!(product_request)

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: product_request.store.organization,
          store: product_request.store,
          action: "requests.customer_request.fulfillment_reversed",
          subject: product_request,
          metadata: { "pos_line_item_id" => @return_line.id, "quantity" => reverse_quantity, "linked_fulfilment_id" => fulfillment.id }
        )

        Result.new(product_request_fulfillment: reversal, success?: true, error: nil, replayed: false)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(product_request_fulfillment: nil, success?: false, error: e.record.errors.full_messages.to_sentence,
                 replayed: false)
    end

    def self.posting_key(return_pos_line_item)
      "pos_line_item:#{return_pos_line_item.id}:fulfillment_reverse"
    end

    private

    def reopen_if_needed!(product_request)
      locked = ProductRequest.lock.find(product_request.id)
      return unless locked.status == "fulfilled"
      return if locked.fulfilled_quantity >= locked.requested_quantity

      locked.update!(status: "open")
    end
  end
end
