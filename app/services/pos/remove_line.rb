# frozen_string_literal: true

module Pos
  # Soft-remove only: retains the line row with status "removed" and releases any
  # active reservation. Never deletes the row.
  class RemoveLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_line_item:, actor:, reason: nil)
      @pos_line_item = pos_line_item
      @actor = actor
      @reason = reason
    end

    def call
      raise Error, "line is not pending" unless @pos_line_item.pending?
      raise Error, "transaction is not open for editing" unless @pos_line_item.pos_transaction.editable?

      ActiveRecord::Base.transaction do
        line = PosLineItem.lock.find(@pos_line_item.id)

        reservation = InventoryReservation.active.find_by(
          source_type: "pos_line_item",
          source_id: line.id
        )
        if reservation
          released = Inventory::ReleaseReservation.call(reservation: reservation, actor: @actor, release_reason: @reason || "line removed")
          raise Error, released.error unless released.success?
        end

        line.update!(
          status: "removed",
          removed_at: Time.current,
          removed_by_user: @actor,
          remove_reason: @reason
        )

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: line.pos_transaction)

        Result.new(pos_line_item: line, success?: true, error: nil,
                   warnings: (recalculation.blockers + recalculation.warnings).uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end
  end
end
