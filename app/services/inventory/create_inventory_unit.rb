# frozen_string_literal: true

module Inventory
  # Phase 4d bootstrap mechanism for individually tracked merchandise, parallel
  # to Phase 3's opening-inventory-adjustment bootstrap for quantity-tracked
  # merchandise: receiving is not implemented until Phase 5, so an authorized
  # user creates the exact Unit directly with its exact acquisition cost.
  class CreateInventoryUnit < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:inventory_unit, :success?, :error)

    def initialize(store:, product_variant:, actor:, acquisition_cost_cents: nil, product_condition: nil,
                    unit_price_cents: nil, acquisition_source: nil, notes: nil, acquired_at: nil)
      @store = store
      @product_variant = product_variant
      @actor = actor
      @acquisition_cost_cents = acquisition_cost_cents
      @product_condition = product_condition
      @unit_price_cents = unit_price_cents
      @acquisition_source = acquisition_source
      @notes = notes
      @acquired_at = acquired_at || Time.current
    end

    def call
      unless Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "inventory.unit.manage") == :allow
        return Result.new(inventory_unit: nil, success?: false, error: "not permitted")
      end
      raise Error, "variant must use individual inventory tracking" unless @product_variant.inventory_tracking_mode == "individual"
      raise Error, "store/variant organization mismatch" unless @store.organization_id == @product_variant.organization.id

      unit = nil
      ActiveRecord::Base.transaction do
        identifier = Identifiers::Generate.call(
          namespace: "27",
          occupied: ->(candidate) { InventoryUnit.exists?(unit_identifier: candidate) }
        )

        unit = InventoryUnit.create!(
          store: @store,
          product_variant: @product_variant,
          unit_identifier: identifier,
          status: "available",
          product_condition: @product_condition,
          acquisition_cost_cents: @acquisition_cost_cents,
          unit_price_cents: @unit_price_cents,
          acquisition_source: @acquisition_source,
          notes: @notes,
          acquired_at: @acquired_at,
          created_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor, organization: @store.organization, store: @store,
          action: "inventory_unit.created", subject: unit,
          metadata: { "unit_identifier" => unit.unit_identifier, "acquisition_cost_cents" => @acquisition_cost_cents }
        )
      end

      Result.new(inventory_unit: unit, success?: true, error: nil)
    rescue Error, ActiveRecord::RecordInvalid, Identifiers::Generate::SequenceOverflowError => e
      Result.new(inventory_unit: nil, success?: false, error: e.message)
    end
  end
end
