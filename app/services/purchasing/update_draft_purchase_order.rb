# frozen_string_literal: true

module Purchasing
  # Updates header attributes and syncs draft Purchase-Order Lines in place.
  # Only permitted while draft; placement locks line identity
  # (vendors-and-purchasing.md#mutability-after-placement).
  #
  # When `can_edit_cost` is false, existing line cost attributes are preserved
  # server-side even if omitted from the submitted params (users without cost
  # permission must not erase protected cost facts by editing quantities).
  class UpdateDraftPurchaseOrder < ApplicationService
    Result = Data.define(:purchase_order, :success?, :error)

    HEADER_ATTRIBUTES = %w[vendor_id buyer_user_id ordered_on expected_on vendor_reference notes].freeze
    COST_ATTRIBUTES = %i[
      cost_entry_method list_cost_cents discount_bps expected_unit_cost_cents cost_provenance
    ].freeze

    def initialize(purchase_order:, attributes:, lines_attributes:, actor:, store:, can_edit_cost: true)
      @purchase_order = purchase_order
      @attributes = attributes.to_h.stringify_keys
      @lines_attributes = Array(lines_attributes)
      @actor = actor
      @store = store
      @can_edit_cost = can_edit_cost
    end

    def call
      unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "purchasing.purchase_order.edit") == :allow
        return failure("not permitted to edit purchase orders")
      end

      ActiveRecord::Base.transaction do
        @purchase_order.reload.lock!
        return failure("only draft purchase orders can be edited") unless @purchase_order.draft?
        return failure("purchase order store mismatch") unless @purchase_order.store_id == @store.id

        @purchase_order.assign_attributes(@attributes.slice(*HEADER_ATTRIBUTES))
        @purchase_order.save!

        sync_lines! if @lines_attributes.present?
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

    def sync_lines!
      keep_ids = []

      @lines_attributes.each_with_index do |attrs, index|
        attrs = attrs.to_h.symbolize_keys
        if attrs[:id].present?
          line = @purchase_order.purchase_order_lines.find(attrs[:id])
          updates = attrs.except(:id, :purchase_order_id)
          COST_ATTRIBUTES.each { |key| updates.delete(key) } unless @can_edit_cost
          line.assign_attributes(updates)
          line.position = attrs[:position].presence || index
          LineSnapshot.apply!(line)
          line.save!
          keep_ids << line.id
        else
          line = build_line!(attrs, index)
          keep_ids << line.id
        end
      end

      @purchase_order.purchase_order_lines.where.not(id: keep_ids).find_each(&:destroy!)
    end

    def build_line!(attrs, index)
      attrs = attrs.to_h.symbolize_keys.except(:id, :purchase_order_id)
      COST_ATTRIBUTES.each { |key| attrs.delete(key) } unless @can_edit_cost
      line = @purchase_order.purchase_order_lines.build(attrs)
      line.position = attrs[:position].presence || index
      LineSnapshot.apply!(line)
      line.save!
      line
    end

    def failure(message)
      Result.new(purchase_order: @purchase_order, success?: false, error: message)
    end
  end
end
