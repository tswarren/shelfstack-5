# frozen_string_literal: true

class CreatePhase5cReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :stores, :next_receipt_number, :bigint, null: false, default: 1
    add_check_constraint :stores, "next_receipt_number >= 1",
      name: "stores_next_receipt_number_positive"

    create_table :receipts do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :vendor, null: false, foreign_key: { on_delete: :restrict }
      t.string :receipt_number, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :received_at
      t.references :received_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :posting_key
      t.datetime :posted_at
      t.references :posted_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :cancelled_at
      t.references :cancelled_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :cancellation_reason
      t.text :notes

      t.timestamps
    end

    add_index :receipts, [ :store_id, :receipt_number ], unique: true, name: "index_receipts_on_store_and_number"
    add_index :receipts, :posting_key, unique: true, where: "(posting_key IS NOT NULL)"
    add_check_constraint :receipts, "status IN ('draft', 'posted', 'cancelled')", name: "receipts_status_check"

    create_table :receipt_lines do |t|
      t.references :receipt, null: false, foreign_key: { on_delete: :restrict }
      t.integer :position, null: false, default: 0
      t.references :product_variant, null: false, foreign_key: { on_delete: :restrict }
      t.references :purchase_order_line, foreign_key: { on_delete: :restrict }
      t.integer :delivered_quantity, null: false
      t.integer :accepted_quantity, null: false, default: 0
      t.integer :rejected_quantity, null: false, default: 0
      t.integer :accepted_unavailable_quantity, null: false, default: 0
      t.integer :actual_unit_cost_cents
      t.string :cost_quality
      t.string :cost_provenance
      t.string :discrepancy_reason
      t.text :notes

      t.timestamps
    end

    add_index :receipt_lines, [ :receipt_id, :position ], name: "index_receipt_lines_on_receipt_and_position"
    add_check_constraint :receipt_lines, "delivered_quantity >= 0", name: "receipt_lines_delivered_nonneg"
    add_check_constraint :receipt_lines, "accepted_quantity >= 0", name: "receipt_lines_accepted_nonneg"
    add_check_constraint :receipt_lines, "rejected_quantity >= 0", name: "receipt_lines_rejected_nonneg"
    add_check_constraint :receipt_lines, "accepted_unavailable_quantity >= 0",
      name: "receipt_lines_accepted_unavailable_nonneg"
    add_check_constraint :receipt_lines, "accepted_unavailable_quantity <= accepted_quantity",
      name: "receipt_lines_accepted_unavailable_within_accepted"
    add_check_constraint :receipt_lines, "accepted_quantity + rejected_quantity <= delivered_quantity",
      name: "receipt_lines_accepted_rejected_within_delivered"
    add_check_constraint :receipt_lines, "actual_unit_cost_cents IS NULL OR actual_unit_cost_cents >= 0",
      name: "receipt_lines_unit_cost_nonneg"
    add_check_constraint :receipt_lines,
      "cost_quality IS NULL OR cost_quality IN ('actual', 'estimated', 'unknown', 'confirmed_zero')",
      name: "receipt_lines_cost_quality_check"

    # OD-014 memorandum deficit-cost pool (Store-and-Variant aggregate, not an
    # inventory asset). Column defaults (0 / "unknown") match the existing
    # zero-state convention so pre-existing StockBalance.create! call sites
    # that do not set these fields remain valid; only the fully-resolved
    # (on_hand >= 0) state is constrained at the database level — the
    # negative/deficit-in-progress state is maintained by Inventory posting
    # services, matching how positive-side value nullability already works.
    add_column :stock_balances, :open_provisional_deficit_cost_cents, :bigint, default: 0
    add_column :stock_balances, :deficit_cost_quality, :string, null: false, default: "unknown"
    add_check_constraint :stock_balances,
      "deficit_cost_quality IN ('actual', 'estimated', 'mixed', 'unknown')",
      name: "stock_balances_deficit_cost_quality_check"
    add_check_constraint :stock_balances,
      "open_provisional_deficit_cost_cents IS NULL OR open_provisional_deficit_cost_cents >= 0",
      name: "stock_balances_deficit_cost_nonneg"
    add_check_constraint :stock_balances,
      "on_hand < 0 OR (open_provisional_deficit_cost_cents = 0 AND deficit_cost_quality = 'unknown')",
      name: "stock_balances_deficit_zero_state"

    # Extend the Inventory Ledger for OD-014 Phase 5 receipt settlement.
    remove_check_constraint :inventory_ledger_entries, name: "inv_ledger_movement_type"
    add_check_constraint :inventory_ledger_entries,
      "movement_type::text = ANY (ARRAY['opening_inventory', 'quantity_adjustment', 'cost_correction', 'sale', 'customer_return', 'receipt', 'receipt_deficit_settlement']::text[])",
      name: "inv_ledger_movement_type"

    # Settlement memorandum facts retained directly on the settlement entry
    # (OD-014 "Recommended ledger behavior" / "Monetary treatment") rather
    # than a separate variance table.
    add_column :inventory_ledger_entries, :provisional_cost_released_cents, :bigint
    add_column :inventory_ledger_entries, :provisional_deficit_cost_quality_snapshot, :string
    add_column :inventory_ledger_entries, :settlement_variance_cents, :bigint
    add_column :inventory_ledger_entries, :settlement_variance_kind, :string

    add_check_constraint :inventory_ledger_entries,
      "provisional_deficit_cost_quality_snapshot IS NULL OR provisional_deficit_cost_quality_snapshot IN ('actual', 'estimated', 'mixed', 'unknown')",
      name: "inv_ledger_deficit_quality_snapshot_check"
    add_check_constraint :inventory_ledger_entries,
      "settlement_variance_kind IS NULL OR settlement_variance_kind IN ('ordinary', 'late_cost_recognition')",
      name: "inv_ledger_variance_kind_check"
  end
end
