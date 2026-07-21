# frozen_string_literal: true

module Inventory
  # Posts inventory effects for a completed linked return line.
  #
  # Disposition effects (quantity-tracked / individual):
  # - return_to_stock     → on_hand + qty / unit available
  # - inspection_required → on_hand + qty and unavailable + qty / unit inspection
  # - damaged             → on_hand + qty and unavailable + qty / unit damaged
  # - return_to_vendor    → on_hand + qty and unavailable + qty / unit rtv
  # - discard             → customer_return then outbound quantity_adjustment / unit discarded
  # - non_inventory       → no stock effect when original tracking mode is none
  class PostCustomerReturn < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:ledger_entry, :inventory_unit, :success?, :error, :warnings, :replayed)

    UNAVAILABLE_DISPOSITIONS = %w[inspection_required damaged return_to_vendor].freeze
    UNIT_STATUS_BY_DISPOSITION = {
      "return_to_stock" => "available",
      "inspection_required" => "inspection",
      "damaged" => "damaged",
      "return_to_vendor" => "rtv",
      "discard" => "discarded"
    }.freeze

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
        restore_stock(line, variant, unavailable_delta: 0, unit_status: "available")
      when *UNAVAILABLE_DISPOSITIONS
        restore_stock(line, variant,
                      unavailable_delta: line.quantity,
                      unit_status: UNIT_STATUS_BY_DISPOSITION.fetch(line.return_disposition))
      when "discard"
        discard_stock(line, variant)
      when "non_inventory"
        if variant.inventory_tracking_mode == "none"
          Result.new(ledger_entry: nil, inventory_unit: nil, success?: true, error: nil, warnings: [], replayed: false)
        else
          raise Error, "non_inventory disposition requires a non-inventory variant"
        end
      else
        raise Error, "unsupported return disposition"
      end
    rescue Error, ActiveRecord::RecordInvalid, PostLedgerEntry::Error => e
      Result.new(ledger_entry: nil, inventory_unit: nil, success?: false, error: e.message, warnings: [], replayed: false)
    end

    def self.posting_key(pos_line_item)
      "pos_line_item:#{pos_line_item.id}:customer_return"
    end

    def self.discard_posting_key(pos_line_item)
      "pos_line_item:#{pos_line_item.id}:customer_return_discard"
    end

    private

    def restore_stock(line, variant, unavailable_delta:, unit_status:)
      case variant.inventory_tracking_mode
      when "quantity"
        restore_quantity(line, variant, unavailable_delta: unavailable_delta)
      when "individual"
        restore_unit(line, unit_status: unit_status)
      when "none"
        Result.new(ledger_entry: nil, inventory_unit: nil, success?: true, error: nil, warnings: [], replayed: false)
      else
        raise Error, "unsupported tracking mode"
      end
    end

    def discard_stock(line, variant)
      case variant.inventory_tracking_mode
      when "quantity"
        inbound = restore_quantity(line, variant, unavailable_delta: 0)
        return inbound unless inbound.success?
        return inbound if inbound.replayed && InventoryLedgerEntry.exists?(posting_key: self.class.discard_posting_key(line))

        discard = PostLedgerEntry.call(
          store: line.pos_transaction.store,
          product_variant: variant,
          quantity_delta: -line.quantity,
          movement_type: "quantity_adjustment",
          movement_kind: :customer_return_discard,
          posting_key: self.class.discard_posting_key(line),
          source: line,
          posted_by_user: @posted_by_user,
          posted_at: @posted_at,
          incoming_unit_cost_cents: line.cost_unit_cost_cents || 0,
          incoming_cost_method: line.cost_method_snapshot.presence || "explicit",
          incoming_cost_quality: line.cost_quality_snapshot.presence || "actual",
          reason_code: "customer_return_discard",
          reason_note: "Discarded after linked customer return"
        )
        Result.new(ledger_entry: discard.ledger_entry, inventory_unit: nil, success?: true,
                   error: nil, warnings: [], replayed: discard.replayed)
      when "individual"
        restore_unit(line, unit_status: "discarded")
      when "none"
        Result.new(ledger_entry: nil, inventory_unit: nil, success?: true, error: nil, warnings: [], replayed: false)
      else
        raise Error, "unsupported tracking mode"
      end
    end

    def restore_quantity(line, variant, unavailable_delta:)
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
          incoming_cost_quality: quality,
          unavailable_delta: unavailable_delta,
          availability_reason: unavailable_delta.positive? ? line.return_disposition : nil
        )

        Result.new(ledger_entry: result.ledger_entry, inventory_unit: nil, success?: true,
                   error: nil, warnings: [], replayed: result.replayed)
      end
    end

    def restore_unit(line, unit_status:)
      unit = line.inventory_unit
      raise Error, "return line requires inventory unit" if unit.blank?

      ActiveRecord::Base.transaction do
        locked = InventoryUnit.lock.find(unit.id)
        if locked.status == unit_status && locked.sold_pos_line_item_id.nil?
          return Result.new(ledger_entry: nil, inventory_unit: locked, success?: true,
                            error: nil, warnings: [], replayed: true)
        end
        raise Error, "unit is not sold" unless locked.status == "sold"
        unless locked.sold_pos_line_item_id == line.original_pos_line_item_id
          raise Error, "unit was not sold on the original line"
        end

        locked.update!(status: unit_status, sold_at: nil, sold_pos_line_item_id: nil)
        Result.new(ledger_entry: nil, inventory_unit: locked, success?: true,
                   error: nil, warnings: [], replayed: false)
      end
    end
  end
end
