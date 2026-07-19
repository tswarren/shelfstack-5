# frozen_string_literal: true

module Pos
  # Open-Ring lines require a postable Department and a price; they reference no
  # Product Variant and create no Inventory Reservation. Blank user-entered
  # description resolves (and is snapshotted) as the Department name.
  class AddOpenRingLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_transaction:, department:, unit_price_cents:, actor:, quantity: 1, description: nil)
      @pos_transaction = pos_transaction
      @department = department
      @unit_price_cents = unit_price_cents.to_i
      @quantity = quantity.to_i
      @description = description
      @actor = actor
    end

    def call
      raise Error, "transaction is not open for editing" unless @pos_transaction.editable?
      raise Error, "quantity must be positive" unless @quantity.positive?
      raise Error, "price must not be negative" if @unit_price_cents.negative?
      raise Error, "department is required" if @department.blank?
      raise Error, "department must be postable" unless @department.postable?
      raise Error, "department must be active" unless @department.active?
      unless @department.organization_id == @pos_transaction.store.organization_id
        raise Error, "department must belong to the transaction's organization"
      end

      tax_category = @department.default_tax_category
      raise Error, "department has no default tax category" if tax_category.blank?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        line = PosLineItem.create!(
          pos_transaction: transaction,
          line_kind: "open_ring",
          status: "pending",
          product_variant: nil,
          department: @department,
          tax_category: tax_category,
          description_snapshot: @description.presence || @department.name,
          quantity: @quantity,
          unit_price_cents: @unit_price_cents,
          position: next_position,
          created_by_user: @actor
        )

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)

        Result.new(pos_line_item: line, success?: true, error: nil,
                   warnings: (recalculation.blockers + recalculation.warnings).uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def next_position
      (@pos_transaction.pos_line_items.maximum(:position) || -1) + 1
    end
  end
end
