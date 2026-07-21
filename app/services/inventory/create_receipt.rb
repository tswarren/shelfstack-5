# frozen_string_literal: true

module Inventory
  # Creates a draft Receipt with a store-scoped, never-reused number
  # (parallels Purchasing::CreatePurchaseOrder). Draft Receipt Lines carry no
  # inventory effect until Inventory::PostReceipt runs.
  class CreateReceipt < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:receipt, :success?, :error)
    COST_ATTRIBUTES = %i[actual_unit_cost_cents cost_quality cost_provenance].freeze

    def initialize(receipt:, lines_attributes:, actor:, store:, can_edit_cost: nil)
      @receipt = receipt
      @lines_attributes = Array(lines_attributes)
      @actor = actor
      @store = store
      @can_edit_cost_override = can_edit_cost
    end

    def call
      authorize!
      @can_edit_cost = cost_edit_authorized?

      ActiveRecord::Base.transaction do
        store = Store.lock.find(@store.id)

        @receipt.store = store
        @receipt.status = "draft"
        @receipt.receipt_number = next_number!(store)
        @receipt.save!

        @lines_attributes.each_with_index { |attrs, index| build_line!(attrs, index) }
        raise Error, "receipt must have at least one line" if @receipt.receipt_lines.empty?

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "inventory.receipt.created",
          subject: @receipt,
          metadata: {
            "vendor_id" => @receipt.vendor_id,
            "receipt_number" => @receipt.receipt_number,
            "line_count" => @receipt.receipt_lines.size
          }
        )

        Result.new(receipt: @receipt, success?: true, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(receipt: @receipt, success?: false, error: e.record.errors.full_messages.to_sentence)
    rescue Error => e
      Result.new(receipt: @receipt, success?: false, error: e.message)
    end

    private

    def authorize!
      return if Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.receipt.create") == :allow

      raise Error, "not permitted to create receipts"
    end

    def cost_edit_authorized?
      permitted = Authorization::EvaluatePermission.call(
        user: @actor, store: @store, permission_key: "inventory.cost.view"
      ) == :allow || Authorization::EvaluatePermission.call(
        user: @actor, store: @store, permission_key: "purchasing.cost.view"
      ) == :allow
      return false unless permitted
      return true if @can_edit_cost_override.nil?

      @can_edit_cost_override
    end

    def next_number!(store)
      number = store.next_receipt_number
      store.update!(next_receipt_number: number + 1)
      "#{store.code}-RCPT-#{number.to_s.rjust(6, '0')}"
    end

    def build_line!(attrs, index)
      attrs = attrs.to_h.symbolize_keys.except(:id, :receipt_id)
      COST_ATTRIBUTES.each { |key| attrs.delete(key) } unless @can_edit_cost
      line = @receipt.receipt_lines.build(attrs)
      line.position = attrs[:position].presence || index
      line.save!
    end
  end
end
