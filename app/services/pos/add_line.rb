# frozen_string_literal: true

module Pos
  class AddLine < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings)

    def initialize(pos_transaction:, product_variant:, actor:, quantity: 1, inventory_unit: nil, product_request: nil)
      @pos_transaction = pos_transaction
      @product_variant = product_variant
      @actor = actor
      @quantity = quantity.to_i
      @inventory_unit = inventory_unit
      @product_request = product_request
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
        # Lock order: POS Transaction → Product Request → Stock Balance/Unit → Reservation.
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        product_request = lock_and_validate_product_request!(transaction)

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
          created_by_user: @actor,
          product_request: product_request
        )

        if @product_variant.inventory_tracking_mode == "quantity"
          warnings.concat(reserve_quantity_for_line!(line, product_request))
        elsif individual
          warnings.concat(reserve_individual_for_line!(line, product_request))
        end

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: @pos_transaction)
        warnings.concat(recalculation.blockers).concat(recalculation.warnings)

        Result.new(pos_line_item: line, success?: true, error: nil, warnings: warnings.uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [])
    end

    private

    def lock_and_validate_product_request!(transaction)
      return nil if @product_request.blank?

      product_request = ProductRequest.lock.find(@product_request.id)
      raise Error, "fulfilment linkage applies only to customer requests" unless product_request.customer_request?
      raise Error, "product request is not open" unless product_request.open?
      raise Error, "product request store mismatch" unless product_request.store_id == transaction.store_id
      unless product_request.compatible_with_variant?(@product_variant)
        raise Error, product_request.compatibility_error_for(@product_variant)
      end

      outstanding = product_request.outstanding_quantity
      if @quantity > outstanding
        raise Error, "quantity exceeds the product request's outstanding quantity (#{outstanding} outstanding)"
      end

      transferable = InventoryReservation.active.where(
        store_id: transaction.store_id,
        product_variant_id: @product_variant.id,
        source_type: "product_request",
        source_id: product_request.id
      ).sum(:quantity)
      additional = [ @quantity - transferable, 0 ].max
      uncovered = product_request.uncovered_quantity
      if additional > uncovered
        raise Error, "quantity exceeds the product request's uncovered quantity (#{uncovered} uncovered)"
      end

      product_request
    end

    # Prefer transferring an existing Product Request reservation to the POS
    # line so the same physical stock is not double-reserved.
    # Lock order: stock balance → reservations (matches Reserve / ReleaseReservation).
    def reserve_quantity_for_line!(line, product_request)
      store = @pos_transaction.store
      balance = Inventory::FindOrCreateStockBalance.call(store: store, product_variant: @product_variant)

      request_reservation = if product_request
        InventoryReservation.active.lock.find_by(
          store_id: store.id, product_variant_id: @product_variant.id,
          source_type: "product_request", source_id: product_request.id
        )
      end

      if request_reservation
        transfer_qty = [ request_reservation.quantity, @quantity ].min

        if transfer_qty == request_reservation.quantity && transfer_qty == @quantity
          request_reservation.update!(source_type: "pos_line_item", source_id: line.id)
          return available_warning(balance)
        end

        if transfer_qty < request_reservation.quantity
          # Split without changing StockBalance.reserved — coverage moves rows only.
          request_reservation.update!(quantity: request_reservation.quantity - transfer_qty)
          InventoryReservation.create!(
            store: store, product_variant: @product_variant,
            source_type: "pos_line_item", source_id: line.id,
            quantity: @quantity, status: "active", reserved_at: Time.current
          )
          return available_warning(balance)
        end

        # Entire request hold transfers; line needs additional free stock.
        new_reserved = balance.reserved - request_reservation.quantity + @quantity
        raise Error, "reserved quantity would go negative" if new_reserved.negative?

        balance.update!(reserved: new_reserved)
        request_reservation.update!(
          status: "released",
          released_at: Time.current,
          released_by_user: @actor,
          release_reason: "transferred_to_pos"
        )
        InventoryReservation.create!(
          store: store, product_variant: @product_variant,
          source_type: "pos_line_item", source_id: line.id,
          quantity: @quantity, status: "active", reserved_at: Time.current
        )
        return available_warning(balance)
      end

      balance.update!(reserved: balance.reserved + @quantity)
      InventoryReservation.create!(
        store: store, product_variant: @product_variant,
        source_type: "pos_line_item", source_id: line.id,
        quantity: @quantity, status: "active", reserved_at: Time.current
      )
      available_warning(balance)
    end

    # Lock order: inventory unit → reservation.
    def reserve_individual_for_line!(line, product_request)
      store = @pos_transaction.store
      unit = InventoryUnit.lock.find(@inventory_unit.id)
      raise Error, "unit belongs to a different store" unless unit.store_id == store.id
      raise Error, "unit belongs to a different variant" unless unit.product_variant_id == @product_variant.id

      request_reservation = if product_request
        InventoryReservation.active.lock.find_by(
          store_id: store.id, product_variant_id: @product_variant.id,
          source_type: "product_request", source_id: product_request.id,
          inventory_unit_id: unit.id
        )
      end

      if request_reservation
        request_reservation.update!(source_type: "pos_line_item", source_id: line.id)
        return []
      end

      # Do not pre-lock a reservation before Reserve — Reserve locks unit then reservation.
      reservation = Inventory::Reserve.call(
        store: store, product_variant: @product_variant, quantity: 1,
        source_type: "pos_line_item", source_id: line.id,
        inventory_unit: unit, actor: @actor
      )
      raise Error, reservation.error unless reservation.success?

      reservation.warnings
    end

    def available_warning(balance)
      balance.available.negative? ? [ "available quantity is negative after reservation" ] : []
    end

    def next_position
      (@pos_transaction.pos_line_items.maximum(:position) || -1) + 1
    end

    def resolved_unit_price_cents(individual)
      return @product_variant.regular_price_cents unless individual

      @inventory_unit.unit_price_cents || @product_variant.regular_price_cents
    end

    def classification
      @classification ||= Catalog::ResolveClassification.call(
        product: @product_variant.product,
        variant: @product_variant
      )
    end
  end
end
