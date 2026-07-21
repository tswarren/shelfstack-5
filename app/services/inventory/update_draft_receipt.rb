# frozen_string_literal: true

module Inventory
  # Updates header attributes and syncs draft Receipt Lines in place. Only
  # permitted while draft (parallels Purchasing::UpdateDraftPurchaseOrder) —
  # posting freezes the Receipt.
  #
  # When `can_edit_cost` is false, existing line cost attributes are preserved
  # server-side even if omitted from the submitted params.
  class UpdateDraftReceipt < ApplicationService
    Result = Data.define(:receipt, :success?, :error)

    HEADER_ATTRIBUTES = %w[vendor_id received_at received_by_user_id notes].freeze
    COST_ATTRIBUTES = %i[actual_unit_cost_cents cost_quality cost_provenance].freeze

    def initialize(receipt:, attributes:, lines_attributes:, actor:, store:, can_edit_cost: nil)
      @receipt = receipt
      @attributes = attributes.to_h.stringify_keys
      @lines_attributes = Array(lines_attributes)
      @actor = actor
      @store = store
      @can_edit_cost_override = can_edit_cost
    end

    def call
      return failure("not permitted to edit receipts") unless authorized?

      ActiveRecord::Base.transaction do
        @receipt.reload.lock!
        return failure("only draft receipts can be edited") unless @receipt.draft?
        return failure("receipt store mismatch") unless @receipt.store_id == @store.id

        @can_edit_cost = cost_edit_authorized?

        @receipt.assign_attributes(@attributes.slice(*HEADER_ATTRIBUTES))
        @receipt.save!

        sync_lines! if @lines_attributes.present?
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

    def sync_lines!
      keep_ids = []

      @lines_attributes.each_with_index do |attrs, index|
        attrs = attrs.to_h.symbolize_keys
        if attrs[:id].present?
          line = @receipt.receipt_lines.find(attrs[:id])
          updates = attrs.except(:id, :receipt_id)
          COST_ATTRIBUTES.each { |key| updates.delete(key) } unless @can_edit_cost
          line.assign_attributes(updates)
          line.position = attrs[:position].presence || index
          apply_suggested_cost!(line) if @can_edit_cost
          line.save!
          keep_ids << line.id
        else
          line = build_line!(attrs, index)
          keep_ids << line.id
        end
      end

      @receipt.receipt_lines.where.not(id: keep_ids).find_each(&:destroy!)
    end

    def build_line!(attrs, index)
      attrs = attrs.to_h.symbolize_keys.except(:id, :receipt_id)
      COST_ATTRIBUTES.each { |key| attrs.delete(key) } unless @can_edit_cost
      line = @receipt.receipt_lines.build(attrs)
      line.position = attrs[:position].presence || index
      apply_suggested_cost!(line) if @can_edit_cost
      line.save!
      line
    end

    def apply_suggested_cost!(line)
      return if line.actual_unit_cost_cents.present?
      return if line.cost_quality == "confirmed_zero"

      suggestion = SuggestReceiptLineCost.call(
        purchase_order_line: line.purchase_order_line,
        product_variant: line.product_variant,
        vendor: @receipt.vendor
      )
      return if suggestion.blank?

      line.actual_unit_cost_cents = suggestion.unit_cost_cents
      line.cost_quality = line.cost_quality.presence || suggestion.cost_quality
      line.cost_provenance = line.cost_provenance.presence || suggestion.cost_provenance
    end

    def failure(message)
      Result.new(receipt: @receipt, success?: false, error: message)
    end
  end
end
