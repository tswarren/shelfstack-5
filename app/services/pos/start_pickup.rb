# frozen_string_literal: true

module Pos
  # Ready-state first valid work: open (or reuse) a transaction and add a line
  # linked to an open customer Product Request. Never leaves an empty open
  # transaction on failure.
  class StartPickup < ApplicationService
    Result = Data.define(:success?, :pos_transaction, :pos_line_item, :error)

    def initialize(pos_session:, actor:, product_request:, quantity: 1)
      @pos_session = pos_session
      @actor = actor
      @product_request = product_request
      @quantity = quantity.to_i
    end

    def call
      return failure("POS session is not open.") unless @pos_session.open?
      return failure("Select a customer request.") if @product_request.blank?
      return failure("quantity must be positive") unless @quantity.positive?

      add_error = nil
      result = ActiveRecord::Base.transaction(requires_new: true) do
        session = PosSession.lock.find(@pos_session.id)
        unless session.open?
          next failure("POS session is not open.")
        end

        request = ProductRequest.lock.find(@product_request.id)
        unless request.customer_request? && request.open?
          next failure("Select an open customer request.")
        end
        unless request.store_id == session.store_id
          next failure("Product request store mismatch.")
        end
        if @quantity > request.outstanding_quantity
          next failure("quantity exceeds the product request's outstanding quantity (#{request.outstanding_quantity} outstanding)")
        end

        variant, inventory_unit, resolve_error = resolve_variant_and_unit!(request, session.store)
        if resolve_error
          next failure(resolve_error)
        end

        can_open = Authorization::EvaluatePermission.call(
          user: @actor, store: session.store, permission_key: "pos.transaction.open"
        ) == :allow
        opened = FindOrOpenActiveTransaction.call(
          pos_session: session,
          actor: @actor,
          create_if_missing: can_open
        )
        unless opened.success?
          next failure(
            can_open ? opened.error : "missing permission pos.transaction.open"
          )
        end
        transaction = opened.pos_transaction

        unless opened.created?
          consume = ConsumeStagedCustomer.call(
            pos_session: session, pos_transaction: transaction, actor: @actor
          )
          if consume.conflict?
            next Result.new(
              success?: false,
              pos_transaction: transaction,
              pos_line_item: nil,
              error: "Staged customer was not attached because this transaction already has a different customer."
            )
          end
          transaction.reload
        end

        add = AddLine.call(
          pos_transaction: transaction,
          product_variant: variant,
          quantity: @quantity,
          actor: @actor,
          inventory_unit: inventory_unit,
          product_request: request
        )
        unless add.success?
          add_error = add.error
          raise ActiveRecord::Rollback
        end

        Result.new(success?: true, pos_transaction: transaction, pos_line_item: add.pos_line_item, error: nil)
      end

      result || failure(add_error.presence || "Unable to start pickup work.")
    end

    private

    def resolve_variant_and_unit!(request, store)
      variant = request.product_variant
      if variant.blank?
        variants = request.product.product_variants.where(status: "active", sellable: true).to_a
        return [ nil, nil, "This customer request has no resolved variant." ] if variants.empty?
        return [ nil, nil, "This customer request has multiple variants; resolve the variant on the request first." ] if variants.size > 1

        variant = variants.first
      end

      inventory_unit = nil
      if variant.inventory_tracking_mode == "individual"
        reservation = InventoryReservation.active.find_by(
          store_id: store.id,
          product_variant_id: variant.id,
          source_type: "product_request",
          source_id: request.id
        )
        inventory_unit = reservation&.inventory_unit
        if inventory_unit.blank?
          return [ nil, nil, "Reserve an inventory unit on the request before pickup, or scan the unit in Transaction." ]
        end
      end

      [ variant, inventory_unit, nil ]
    end

    def failure(message)
      Result.new(success?: false, pos_transaction: nil, pos_line_item: nil, error: message)
    end
  end
end
