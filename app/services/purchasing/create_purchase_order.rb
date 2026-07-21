# frozen_string_literal: true

module Purchasing
  # Creates a draft Purchase Order with a store-scoped, never-reused number
  # (architectural-locks.md#purchase-order-commercial-lifecycle-phase-5) and
  # currency defaulted from the receiving Store's operating currency.
  class CreatePurchaseOrder < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:purchase_order, :success?, :error)

    def initialize(purchase_order:, lines_attributes:, actor:, store:)
      @purchase_order = purchase_order
      @lines_attributes = Array(lines_attributes)
      @actor = actor
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        store = Store.lock.find(@store.id)

        @purchase_order.store = store
        @purchase_order.status = "draft"
        @purchase_order.currency_code = store.currency_code
        @purchase_order.purchase_order_number = next_number!(store)
        @purchase_order.save!

        @lines_attributes.each_with_index { |attrs, index| build_line!(attrs, index) }
        raise Error, "purchase order must have at least one line" if @purchase_order.purchase_order_lines.empty?

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "purchasing.purchase_order.created",
          subject: @purchase_order,
          metadata: {
            "vendor_id" => @purchase_order.vendor_id,
            "purchase_order_number" => @purchase_order.purchase_order_number,
            "line_count" => @purchase_order.purchase_order_lines.size
          }
        )

        Result.new(purchase_order: @purchase_order, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.record.errors.full_messages.to_sentence)
    rescue Error => e
      Result.new(purchase_order: @purchase_order, success?: false, error: e.message)
    end

    private

    def next_number!(store)
      number = store.next_purchase_order_number
      store.update!(next_purchase_order_number: number + 1)
      "#{store.code}-PO-#{number.to_s.rjust(5, "0")}"
    end

    def build_line!(attrs, index)
      attrs = attrs.to_h.symbolize_keys.except(:id, :purchase_order_id)
      line = @purchase_order.purchase_order_lines.build(attrs)
      line.position = attrs[:position].presence || index
      LineSnapshot.apply!(line)
      line.save!
    end
  end
end
