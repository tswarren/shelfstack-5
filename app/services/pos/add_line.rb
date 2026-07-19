# frozen_string_literal: true

module Pos
  class AddLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_transaction:, product_variant:, actor:, quantity: 1)
      @pos_transaction = pos_transaction
      @product_variant = product_variant
      @actor = actor
      @quantity = quantity.to_i
    end

    def call
      raise Error, "transaction is not open for editing" unless @pos_transaction.editable?
      raise Error, "quantity must be positive" unless @quantity.positive?

      eligibility = Catalog::SaleEligibility.call(variant: @product_variant, store: @pos_transaction.store)
      raise Error, "not eligible for sale: #{eligibility.blockers.join(', ')}" if eligibility.blockers.any?

      if @product_variant.inventory_tracking_mode == "individual"
        raise Error, "individually tracked variants are not supported before Phase 4d"
      end

      department = resolved_department
      raise Error, "no postable department resolved for variant" if department.blank?

      warnings = eligibility.warnings.dup

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        line = PosLineItem.create!(
          pos_transaction: transaction,
          line_kind: "product",
          status: "pending",
          product_variant: @product_variant,
          department: department,
          tax_category: resolved_tax_category(department),
          quantity: @quantity,
          unit_price_cents: @product_variant.regular_price_cents,
          position: next_position,
          created_by_user: @actor
        )

        if @product_variant.inventory_tracking_mode == "quantity"
          reservation = Inventory::Reserve.call(
            store: @pos_transaction.store,
            product_variant: @product_variant,
            quantity: @quantity,
            source_type: "pos_line_item",
            source_id: line.id,
            actor: @actor
          )
          raise Error, reservation.error unless reservation.success?

          warnings.concat(reservation.warnings)
        end

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: @pos_transaction)
        warnings.concat(recalculation.blockers).concat(recalculation.warnings)

        Result.new(pos_line_item: line, success?: true, error: nil, warnings: warnings.uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def next_position
      (@pos_transaction.pos_line_items.maximum(:position) || -1) + 1
    end

    # Mirrors Catalog::SaleEligibility resolution order (variant override → product
    # default → merchandise class default; tax additionally falls back to department).
    def resolved_merchandise_class
      @product_variant.merchandise_class || @product_variant.product.merchandise_class
    end

    def resolved_department
      merchandise_class = resolved_merchandise_class
      @product_variant.department ||
        @product_variant.product.default_department ||
        merchandise_class&.default_department
    end

    def resolved_tax_category(department)
      merchandise_class = resolved_merchandise_class
      @product_variant.tax_category ||
        @product_variant.product.default_tax_category ||
        merchandise_class&.default_tax_category ||
        department&.default_tax_category
    end
  end
end
