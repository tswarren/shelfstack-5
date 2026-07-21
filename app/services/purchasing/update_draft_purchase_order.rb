# frozen_string_literal: true

module Purchasing
  # Updates header attributes and replaces the full line set of a draft
  # Purchase Order. Only permitted while draft; placement locks line identity
  # (vendors-and-purchasing.md#mutability-after-placement).
  class UpdateDraftPurchaseOrder < ApplicationService
    Result = Data.define(:purchase_order, :success?, :error)

    HEADER_ATTRIBUTES = %w[vendor_id buyer_user_id ordered_on expected_on vendor_reference notes].freeze

    def initialize(purchase_order:, attributes:, lines_attributes:, actor:, store:)
      @purchase_order = purchase_order
      @attributes = attributes.to_h.stringify_keys
      @lines_attributes = Array(lines_attributes)
      @actor = actor
      @store = store
    end

    def call
      ActiveRecord::Base.transaction do
        @purchase_order.reload.lock!
        return failure("only draft purchase orders can be edited") unless @purchase_order.draft?
        return failure("purchase order store mismatch") unless @purchase_order.store_id == @store.id

        @purchase_order.assign_attributes(@attributes.slice(*HEADER_ATTRIBUTES))
        @purchase_order.save!

        if @lines_attributes.present?
          @purchase_order.purchase_order_lines.destroy_all
          @lines_attributes.each_with_index { |attrs, index| build_line!(attrs, index) }
        end
        return failure("purchase order must have at least one line") if @purchase_order.purchase_order_lines.empty?

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "purchasing.purchase_order.updated",
          subject: @purchase_order,
          metadata: {
            "vendor_id" => @purchase_order.vendor_id,
            "line_count" => @purchase_order.purchase_order_lines.count
          }
        )

        Result.new(purchase_order: @purchase_order.reload, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def build_line!(attrs, index)
      attrs = attrs.to_h.symbolize_keys.except(:id, :purchase_order_id)
      line = @purchase_order.purchase_order_lines.build(attrs)
      line.position = attrs[:position].presence || index
      LineSnapshot.apply!(line)
      line.save!
    end

    def failure(message)
      Result.new(purchase_order: @purchase_order, success?: false, error: message)
    end
  end
end
