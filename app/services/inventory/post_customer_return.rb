# frozen_string_literal: true

module Inventory
  # Posts inventory effects for a completed linked return line.
  # return_to_stock restores quantity On Hand (or unit availability).
  # Other dispositions do not restore sellable stock in Phase 4e.
  class PostCustomerReturn < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:ledger_entry, :inventory_unit, :success?, :error, :warnings, :replayed)

    def initialize(pos_line_item:, posted_by_user:, posted_at: nil)
      @pos_line_item = pos_line_item
      @posted_by_user = posted_by_user
      @posted_at = posted_at || Time.current
    end

    def call
      line = @pos_line_item
      raise Error, "line must be a return" unless line.direction == "return"
      raise Error, "line must be product" unless line.line_kind == "product"

      variant = line.product_variant
      raise Error, "line has no product variant" if variant.blank?

      case line.return_disposition
      when "return_to_stock"
        restore_stock(line, variant)
      when "inspection_required", "damaged", "return_to_vendor", "discard", "non_inventory"
        Result.new(ledger_entry: nil, inventory_unit: line.inventory_unit, success?: true,
                   error: nil, warnings: [ "disposition #{line.return_disposition} does not restore sellable stock" ],
                   replayed: false)
      else
        raise Error, "unsupported return disposition"
      end
    rescue Error, ActiveRecord::RecordInvalid, PostLedgerEntry::Error => e
      Result.new(ledger_entry: nil, inventory_unit: nil, success?: false, error: e.message, warnings: [], replayed: false)
    end

    def self.posting_key(pos_line_item)
      "pos_line_item:#{pos_line_item.id}:customer_return"
    end

    private

    def restore_stock(line, variant)
      case variant.inventory_tracking_mode
      when "quantity"
        restore_quantity(line, variant)
      when "individual"
        restore_unit(line)
      when "none"
        Result.new(ledger_entry: nil, inventory_unit: nil, success?: true, error: nil, warnings: [], replayed: false)
      else
        raise Error, "unsupported tracking mode"
      end
    end

    def restore_quantity(line, variant)
      store = line.pos_transaction.store
      posting_key = self.class.posting_key(line)
      unit_cost = line.cost_unit_cost_cents
      quality = line.cost_quality_snapshot.presence || "unknown"
      method = line.cost_method_snapshot.presence || "unknown"

      ActiveRecord::Base.transaction do
        existing = InventoryLedgerEntry.find_by(posting_key: posting_key)
        if existing
          return Result.new(ledger_entry: existing, inventory_unit: nil, success?: true,
                            error: nil, warnings: [], replayed: true)
        end

        result = PostLedgerEntry.call(
          store: store,
          product_variant: variant,
          quantity_delta: line.quantity,
          movement_type: "customer_return",
          posting_key: posting_key,
          source: line,
          posted_by_user: @posted_by_user,
          posted_at: @posted_at,
          incoming_unit_cost_cents: unit_cost,
          incoming_cost_method: method,
          incoming_cost_quality: quality
        )

        Result.new(ledger_entry: result.ledger_entry, inventory_unit: nil, success?: true,
                   error: nil, warnings: [], replayed: result.replayed)
      end
    end

    def restore_unit(line)
      unit = line.inventory_unit
      raise Error, "return line requires inventory unit" if unit.blank?

      ActiveRecord::Base.transaction do
        locked = InventoryUnit.lock.find(unit.id)
        if locked.status == "available"
          return Result.new(ledger_entry: nil, inventory_unit: locked, success?: true,
                            error: nil, warnings: [], replayed: true)
        end
        raise Error, "unit is not sold" unless locked.status == "sold"
        # Domain: "Individual unit returns restore unit to available if
        # return_to_stock and unit was sold on original line" — guards against
        # restoring a unit that was resold or re-sourced after the original
        # sale (never expected in Phase 4e's single-return-per-unit flow, but
        # kept as an explicit invariant rather than an implicit assumption).
        unless locked.sold_pos_line_item_id == line.original_pos_line_item_id
          raise Error, "unit was not sold on the original line"
        end

        locked.update!(status: "available", sold_at: nil, sold_pos_line_item_id: nil)
        Result.new(ledger_entry: nil, inventory_unit: locked, success?: true,
                   error: nil, warnings: [], replayed: false)
      end
    end
  end
end
