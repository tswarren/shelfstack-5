# frozen_string_literal: true

module Inventory
  # Updates header attributes and replaces the full line set of a draft
  # Receipt. Only permitted while draft (parallels
  # Purchasing::UpdateDraftPurchaseOrder) — posting freezes the Receipt.
  class UpdateDraftReceipt < ApplicationService
    Result = Data.define(:receipt, :success?, :error)

    HEADER_ATTRIBUTES = %w[vendor_id received_at received_by_user_id notes].freeze

    def initialize(receipt:, attributes:, lines_attributes:, actor:, store:)
      @receipt = receipt
      @attributes = attributes.to_h.stringify_keys
      @lines_attributes = Array(lines_attributes)
      @actor = actor
      @store = store
    end

    def call
      return failure("not permitted to edit receipts") unless authorized?

      ActiveRecord::Base.transaction do
        @receipt.reload.lock!
        return failure("only draft receipts can be edited") unless @receipt.draft?
        return failure("receipt store mismatch") unless @receipt.store_id == @store.id

        @receipt.assign_attributes(@attributes.slice(*HEADER_ATTRIBUTES))
        @receipt.save!

        if @lines_attributes.present?
          @receipt.receipt_lines.destroy_all
          @lines_attributes.each_with_index { |attrs, index| build_line!(attrs, index) }
        end
        return failure("receipt must have at least one line") if @receipt.receipt_lines.empty?

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "inventory.receipt.updated",
          subject: @receipt,
          metadata: {
            "vendor_id" => @receipt.vendor_id,
            "line_count" => @receipt.receipt_lines.count
          }
        )

        Result.new(receipt: @receipt.reload, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def authorized?
      Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.receipt.create") == :allow
    end

    def build_line!(attrs, index)
      attrs = attrs.to_h.symbolize_keys.except(:id, :receipt_id)
      line = @receipt.receipt_lines.build(attrs)
      line.position = attrs[:position].presence || index
      line.save!
    end

    def failure(message)
      Result.new(receipt: @receipt, success?: false, error: message)
    end
  end
end
