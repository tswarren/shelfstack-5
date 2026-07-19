# frozen_string_literal: true

module Inventory
  # POS completion's inventory-sale bridge: converts the active Reservation on
  # a quantity- or individually tracked POS product line into a posted sale.
  #
  # Deliberately NOT "post sale, then Release": Release marks a Reservation
  # `released` (available again) and is for cancellation/removal, not completion.
  #
  # Quantity-tracked (D1, Phase 4c): locks the Stock Balance then the
  # Reservation (matching the Reserve/ReleaseReservation lock order), posts the
  # outbound sale through `PostLedgerEntry` (deterministic `posting_key` keyed
  # on the line), decrements `reserved`, and marks the Reservation `converted`.
  #
  # Individually tracked (Phase 4d): locks the exact Inventory Unit then the
  # Reservation, marks the Unit `sold`, and marks the Reservation `converted`.
  # No aggregate Stock Balance / ledger entry exists for individually tracked
  # variants (ADR-0001: cost model is the exact Unit acquisition cost, not a
  # Store-and-Variant moving average) — the Unit status transition is itself
  # the posted inventory movement, and is audited directly.
  #
  # Both branches snapshot cost onto the line at conversion so completed cost
  # snapshots remain immutable regardless of later inventory changes.
  class ConvertReservation < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:reservation, :ledger_entry, :stock_balance, :inventory_unit, :success?, :error, :warnings, :replayed)

    def initialize(pos_line_item:, posted_by_user:, posted_at: nil)
      @pos_line_item = pos_line_item
      @posted_by_user = posted_by_user
      @posted_at = posted_at || Time.current
    end

    def call
      line = @pos_line_item
      variant = line.product_variant
      raise Error, "line has no product variant" if variant.blank?

      case variant.inventory_tracking_mode
      when "quantity"
        convert_quantity(line, variant)
      when "individual"
        convert_individual(line, variant)
      else
        raise Error, "variant is not inventory-tracked for conversion"
      end
    rescue Error, ActiveRecord::RecordInvalid, PostLedgerEntry::Error => e
      Result.new(reservation: nil, ledger_entry: nil, stock_balance: nil, inventory_unit: nil,
                 success?: false, error: e.message, warnings: [], replayed: false)
    end

    def self.posting_key(pos_line_item)
      "pos_line_item:#{pos_line_item.id}:sale"
    end

    private

    def convert_quantity(line, variant)
      store = line.pos_transaction.store
      posting_key = self.class.posting_key(line)

      ActiveRecord::Base.transaction do
        # Lock order: stock balance -> reservation (matches Reserve / ReleaseReservation).
        balance = FindOrCreateStockBalance.call(store: store, product_variant: variant)
        reservation = InventoryReservation.lock.find_by(
          store_id: store.id, product_variant_id: variant.id,
          source_type: "pos_line_item", source_id: line.id
        )
        raise Error, "no reservation found for line" if reservation.blank?

        if reservation.status == "converted"
          existing_entry = InventoryLedgerEntry.find_by(posting_key: posting_key)
          return Result.new(reservation: reservation, ledger_entry: existing_entry, stock_balance: balance, inventory_unit: nil,
                             success?: true, error: nil, warnings: [], replayed: true)
        end

        raise Error, "reservation is not active" unless reservation.status == "active"
        unless reservation.quantity == line.quantity
          raise Error, "reservation quantity does not match line quantity"
        end

        post = PostLedgerEntry.call(
          store: store, product_variant: variant, movement_type: "sale", movement_kind: :sale,
          quantity_delta: -line.quantity, source: line, posting_key: posting_key,
          posted_by_user: @posted_by_user, posted_at: @posted_at
        )

        balance.reload
        new_reserved = balance.reserved - reservation.quantity
        raise Error, "reserved quantity would go negative" if new_reserved.negative?

        balance.update!(reserved: new_reserved)
        reservation.update!(status: "converted", converted_at: @posted_at)

        # OD-014: snapshot the (possibly provisional) outbound cost onto the line
        # at conversion so completed cost snapshots remain immutable regardless of
        # later Stock Balance changes.
        line.update!(
          cost_unit_cost_cents: post.ledger_entry.unit_cost_cents,
          cost_extended_cents: post.ledger_entry.movement_cost_cents,
          cost_method_snapshot: post.ledger_entry.cost_method,
          cost_quality_snapshot: post.ledger_entry.cost_quality
        )

        warnings = balance.available.negative? ? [ "available quantity is negative after sale" ] : []

        Result.new(reservation: reservation, ledger_entry: post.ledger_entry, stock_balance: balance, inventory_unit: nil,
                   success?: true, error: nil, warnings: warnings, replayed: false)
      end
    end

    def convert_individual(line, variant)
      raise Error, "line has no inventory unit" if line.inventory_unit_id.blank?

      store = line.pos_transaction.store

      ActiveRecord::Base.transaction do
        # Lock order: unit -> reservation (parallel to balance -> reservation above).
        unit = InventoryUnit.lock.find(line.inventory_unit_id)
        reservation = InventoryReservation.lock.find_by(
          inventory_unit_id: unit.id, source_type: "pos_line_item", source_id: line.id
        )
        raise Error, "no reservation found for line" if reservation.blank?

        if reservation.status == "converted"
          return Result.new(reservation: reservation, ledger_entry: nil, stock_balance: nil, inventory_unit: unit,
                             success?: true, error: nil, warnings: [], replayed: true)
        end

        raise Error, "reservation is not active" unless reservation.status == "active"
        raise Error, "unit is not reserved" unless unit.status == "reserved"

        unit.update!(status: "sold", sold_at: @posted_at)
        reservation.update!(status: "converted", converted_at: @posted_at)

        line.update!(
          cost_unit_cost_cents: unit.acquisition_cost_cents,
          cost_extended_cents: unit.acquisition_cost_cents,
          cost_method_snapshot: "explicit",
          cost_quality_snapshot: unit.acquisition_cost_cents.present? ? "actual" : "unknown"
        )

        Administration::RecordAuditEvent.call(
          actor: @posted_by_user, organization: variant.organization, store: store,
          action: "inventory_unit.sold", subject: unit,
          metadata: { "pos_line_item_id" => line.id, "unit_identifier" => unit.unit_identifier }
        )

        Result.new(reservation: reservation, ledger_entry: nil, stock_balance: nil, inventory_unit: unit,
                   success?: true, error: nil, warnings: [], replayed: false)
      end
    end
  end
end
