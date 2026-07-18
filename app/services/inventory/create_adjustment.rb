# frozen_string_literal: true

module Inventory
  class CreateAdjustment < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:adjustment, :success?, :error)

    def initialize(adjustment:, lines_attributes:, actor:, store:)
      @adjustment = adjustment
      @lines_attributes = Array(lines_attributes)
      @actor = actor
      @store = store
    end

    def call
      unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.adjustment.create") == :allow
        return Result.new(adjustment: @adjustment, success?: false, error: "not permitted")
      end

      ActiveRecord::Base.transaction do
        @adjustment.store = @store
        @adjustment.created_by_user = @actor
        @adjustment.status = "draft"
        @adjustment.save!

        @lines_attributes.each_with_index do |attrs, index|
          attrs = attrs.to_h.symbolize_keys.except(:id, :inventory_adjustment_id)
          line = @adjustment.inventory_adjustment_lines.build(attrs)
          line.position = attrs[:position].presence || index
          line.save!
        end


        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @store.organization,
          store: @store,
          action: "inventory.adjustment.created",
          subject: @adjustment,
          metadata: {
            "kind" => @adjustment.kind,
            "reason_id" => @adjustment.inventory_adjustment_reason_id,
            "line_count" => @adjustment.inventory_adjustment_lines.count
          }
        )
      end

      Result.new(adjustment: @adjustment, success?: true, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(adjustment: @adjustment, success?: false, error: e.record.errors.full_messages.to_sentence)
    rescue Error => e
      Result.new(adjustment: @adjustment, success?: false, error: e.message)
    end
  end
end
