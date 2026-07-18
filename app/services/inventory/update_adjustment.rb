# frozen_string_literal: true

module Inventory
  class UpdateAdjustment < ApplicationService
    Result = Data.define(:adjustment, :success?, :error)

    def initialize(adjustment:, attributes:, lines_attributes:, actor:, store:)
      @adjustment = adjustment
      @attributes = attributes.to_h.stringify_keys
      @lines_attributes = Array(lines_attributes)
      @actor = actor
      @store = store
    end

    def call
      unless @adjustment.draft?
        return Result.new(adjustment: @adjustment, success?: false, error: "only draft adjustments can be updated")
      end

      unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.adjustment.create") == :allow
        return Result.new(adjustment: @adjustment, success?: false, error: "not permitted")
      end

      ActiveRecord::Base.transaction do
        @adjustment.assign_attributes(@attributes.slice("inventory_adjustment_reason_id", "note", "kind"))
        @adjustment.save!

        if @lines_attributes.present?
          @adjustment.inventory_adjustment_lines.destroy_all
          @lines_attributes.each_with_index do |attrs, index|
            attrs = attrs.to_h.symbolize_keys.except(:id, :inventory_adjustment_id)
            line = @adjustment.inventory_adjustment_lines.build(attrs)
            line.position = attrs[:position].presence || index
            line.save!
          end
        end


        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "inventory.adjustment.updated",
          subject: @adjustment,
          metadata: {
            "kind" => @adjustment.kind,
            "line_count" => @adjustment.inventory_adjustment_lines.count
          }
        )
      end

      Result.new(adjustment: @adjustment.reload, success?: true, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(adjustment: @adjustment, success?: false, error: e.record.errors.full_messages.to_sentence)
    end
  end
end
