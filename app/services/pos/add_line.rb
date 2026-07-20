# frozen_string_literal: true

module Pos
  class AddLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_transaction:, product_variant:, actor:, quantity: 1, inventory_unit: nil)
      @pos_transaction = pos_transaction
      @product_variant = product_variant
      @actor = actor
      @quantity = quantity.to_i
      @inventory_unit = inventory_unit
    end

    def call
      raise Error, "transaction is not open for editing" unless @pos_transaction.editable?
      raise Error, "quantity must be positive" unless @quantity.positive?

      eligibility = Catalog::SaleEligibility.call(variant: @product_variant, store: @pos_transaction.store)
      raise Error, "not eligible for sale: #{eligibility.blockers.join(', ')}" if eligibility.blockers.any?

      individual = @product_variant.inventory_tracking_mode == "individual"
      if individual
        raise Error, "exact inventory unit is required for individually tracked variants" if @inventory_unit.blank?
        raise Error, "quantity must be 1 for individually tracked variants" unless @quantity == 1
        raise Error, "unit belongs to a different variant" unless @inventory_unit.product_variant_id == @product_variant.id
        raise Error, "unit belongs to a different store" unless @inventory_unit.store_id == @pos_transaction.store_id
      end

      department = classification.department
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
          inventory_unit: individual ? @inventory_unit : nil,
          department: department,
          tax_category: classification.tax_category,
          quantity: @quantity,
          unit_price_cents: resolved_unit_price_cents(individual),
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
        elsif individual
          reservation = Inventory::Reserve.call(
            store: @pos_transaction.store,
            product_variant: @product_variant,
            quantity: 1,
            source_type: "pos_line_item",
            source_id: line.id,
            inventory_unit: @inventory_unit,
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

    # An individually tracked Unit may carry its own override price
    # (glossary: "Unit price"); fall back to the variant's regular price.
    def resolved_unit_price_cents(individual)
      return @product_variant.regular_price_cents unless individual

      @inventory_unit.unit_price_cents || @product_variant.regular_price_cents
    end

    # Classification resolves via Catalog::ResolveClassification (variant → product → MC → department).
    def classification
      @classification ||= Catalog::ResolveClassification.call(
        product: @product_variant.product,
        variant: @product_variant
      )
    end
  end
end
