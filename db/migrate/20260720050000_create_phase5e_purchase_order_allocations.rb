# frozen_string_literal: true

# Phase 5e: Purchase-Order Allocations commit expected supply from an
# `ordered` Purchase-Order Line to a Customer Request (ADR-0015 §6, OD-007).
# Resolution (conversion to an Inventory Reservation, or release) is recorded
# through append-only `purchase_order_allocation_events`; the allocation
# itself never persists a received/fulfilled status — remaining quantity is
# always derived (docs/implementation/decisions/od-007-allocation-receipt-and-fulfilment.md).
class CreatePhase5ePurchaseOrderAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_order_allocations do |t|
      t.references :purchase_order_line, null: false, foreign_key: { on_delete: :restrict }
      t.references :product_request, null: false, foreign_key: { on_delete: :restrict }
      t.integer :quantity, null: false
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }

      t.timestamps
    end

    add_index :purchase_order_allocations, [ :purchase_order_line_id, :product_request_id ], unique: true,
      name: "index_po_allocations_on_line_and_request"
    add_check_constraint :purchase_order_allocations, "quantity > 0",
      name: "po_allocations_quantity_positive"

    # Append-only quantity-resolution ledger (OD-007) — no updated_at, mirrors
    # inventory_ledger_entries' append-only shape.
    create_table :purchase_order_allocation_events do |t|
      t.references :purchase_order_allocation, null: false, foreign_key: { on_delete: :restrict }
      t.string :event_type, null: false
      t.integer :quantity, null: false
      t.references :receipt_line, foreign_key: { on_delete: :restrict }
      t.references :inventory_reservation, foreign_key: { on_delete: :restrict }
      t.string :reason
      t.text :note
      t.datetime :occurred_at, null: false
      t.references :user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :posting_key

      t.datetime :created_at, null: false
    end

    add_index :purchase_order_allocation_events, :posting_key, unique: true,
      name: "index_po_allocation_events_on_posting_key"
    add_check_constraint :purchase_order_allocation_events,
      "event_type IN ('converted_to_reservation', 'released')",
      name: "po_allocation_events_event_type_check"
    add_check_constraint :purchase_order_allocation_events, "quantity > 0",
      name: "po_allocation_events_quantity_positive"
    add_check_constraint :purchase_order_allocation_events,
      "reason IS NULL OR reason IN (" \
      "'purchase_order_cancelled', 'line_quantity_cancelled', 'vendor_unavailable', 'received_unavailable', " \
      "'request_cancelled', 'request_quantity_reduced', 'fulfilled_from_earlier_supply', " \
      "'reallocated_to_other_supply', 'manual_release')",
      name: "po_allocation_events_reason_check"
    add_check_constraint :purchase_order_allocation_events,
      "event_type <> 'released' OR reason IS NOT NULL",
      name: "po_allocation_events_released_requires_reason"
  end
end
