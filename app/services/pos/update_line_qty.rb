# frozen_string_literal: true

module Pos
  class UpdateLineQty < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_line_item:, quantity:, actor:)
      @pos_line_item = pos_line_item
      @quantity = quantity.to_i
      @actor = actor
    end

    def call
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "line is not pending" unless @pos_line_item.pending?
      raise Error, "transaction is not open for editing" unless @pos_line_item.pos_transaction.editable?

      warnings = []

      ActiveRecord::Base.transaction do
        line = PosLineItem.lock.find(@pos_line_item.id)

        if line.line_kind == "product" && line.product_variant.inventory_tracking_mode == "quantity"
          reservation = Inventory::Reserve.call(
            store: line.pos_transaction.store,
            product_variant: line.product_variant,
            quantity: @quantity,
            source_type: "pos_line_item",
            source_id: line.id,
            actor: @actor
          )
          raise Error, reservation.error unless reservation.success?

          warnings.concat(reservation.warnings)
        end

        line.update!(quantity: @quantity)

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: line.pos_transaction)
        warnings.concat(recalculation.blockers).concat(recalculation.warnings)

        Result.new(pos_line_item: line, success?: true, error: nil, warnings: warnings.uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end
  end
end
