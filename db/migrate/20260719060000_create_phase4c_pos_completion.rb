# frozen_string_literal: true

class CreatePhase4cPosCompletion < ActiveRecord::Migration[8.1]
  def change
    # OD-002: receipt sequence is owned by the store, locked increment at successful completion only.
    add_column :stores, :next_receipt_sequence, :bigint, null: false, default: 1
    add_check_constraint :stores, "next_receipt_sequence >= 1", name: "stores_next_receipt_sequence_positive"

    # D1: extend the inventory ledger for sale (outbound) postings and the OD-014
    # provisional last-known cost method used when the current moving average is
    # unavailable (on_hand <= 0) but a positive carrying rate was previously known.
    remove_check_constraint :inventory_ledger_entries, name: "inv_ledger_movement_type"
    add_check_constraint :inventory_ledger_entries,
                          "movement_type IN ('opening_inventory', 'quantity_adjustment', 'cost_correction', 'sale')",
                          name: "inv_ledger_movement_type"

    remove_check_constraint :inventory_ledger_entries, name: "inv_ledger_cost_method"
    add_check_constraint :inventory_ledger_entries,
                          "cost_method IN ('explicit', 'configured_estimate', 'moving_average', 'last_known', 'unknown')",
                          name: "inv_ledger_cost_method"

    # D1: cost snapshot on POS product lines at reservation-conversion (sale posting) time.
    add_column :pos_line_items, :cost_unit_cost_cents, :integer
    add_column :pos_line_items, :cost_extended_cents, :integer
    add_column :pos_line_items, :cost_method_snapshot, :string
    add_column :pos_line_items, :cost_quality_snapshot, :string
    add_column :pos_line_items, :completed_at, :datetime

    add_check_constraint :pos_line_items, "cost_unit_cost_cents IS NULL OR cost_unit_cost_cents >= 0",
                          name: "pos_line_items_cost_unit_cost_non_negative"
    add_check_constraint :pos_line_items, "cost_extended_cents IS NULL OR cost_extended_cents >= 0",
                          name: "pos_line_items_cost_extended_non_negative"
    add_check_constraint :pos_line_items,
                          "cost_quality_snapshot IS NULL OR cost_quality_snapshot IN ('actual', 'estimated', 'mixed', 'unknown')",
                          name: "pos_line_items_cost_quality_snapshot_check"
    add_check_constraint :pos_line_items,
                          "cost_method_snapshot IS NULL OR cost_method_snapshot IN ('explicit', 'configured_estimate', 'moving_average', 'last_known', 'unknown')",
                          name: "pos_line_items_cost_method_snapshot_check"

    # D2: completion fields on pos_transactions.
    add_column :pos_transactions, :completed_at, :datetime
    add_reference :pos_transactions, :completed_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
    add_reference :pos_transactions, :completed_pos_session, foreign_key: { to_table: :pos_sessions, on_delete: :restrict }
    add_column :pos_transactions, :receipt_number, :string
    add_column :pos_transactions, :receipt_sequence, :bigint
    add_column :pos_transactions, :completion_idempotency_key, :string
    add_column :pos_transactions, :subtotal_cents, :bigint
    add_column :pos_transactions, :discount_total_cents, :bigint
    add_column :pos_transactions, :tax_total_cents, :bigint
    add_column :pos_transactions, :net_total_cents, :bigint

    add_index :pos_transactions, [ :store_id, :receipt_number ], unique: true, where: "receipt_number IS NOT NULL",
              name: "index_pos_transactions_on_store_and_receipt_number"
    add_index :pos_transactions, [ :store_id, :receipt_sequence ], unique: true, where: "receipt_sequence IS NOT NULL",
              name: "index_pos_transactions_on_store_and_receipt_sequence"
    add_index :pos_transactions, :completion_idempotency_key, unique: true,
              where: "completion_idempotency_key IS NOT NULL"

    add_check_constraint :pos_transactions,
                          "status <> 'completed' OR (receipt_number IS NOT NULL AND completed_at IS NOT NULL)",
                          name: "pos_transactions_completed_requires_receipt"

    # D2: pos_tenders (cash / standalone-card stub / split tender).
    create_table :pos_tenders do |t|
      t.references :pos_transaction, null: false, foreign_key: { on_delete: :restrict }
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :tender_type, null: false, foreign_key: { on_delete: :restrict }
      t.string :direction, null: false, default: "received"
      t.string :status, null: false, default: "pending"
      t.integer :amount_cents, null: false
      t.integer :amount_tendered_cents
      t.integer :change_due_cents
      t.string :authorization_code
      t.string :terminal_reference
      t.datetime :authorized_at
      t.boolean :requires_reconciliation, null: false, default: false
      t.datetime :completed_at
      t.datetime :voided_at
      t.references :voided_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :void_reason
      t.datetime :removed_at
      t.references :removed_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :remove_reason
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.timestamps
    end

    add_index :pos_tenders, [ :pos_transaction_id, :status ]
    add_check_constraint :pos_tenders, "direction IN ('received', 'refunded')", name: "pos_tenders_direction_check"
    add_check_constraint :pos_tenders, "status IN ('pending', 'authorized', 'completed', 'voided', 'removed')",
                          name: "pos_tenders_status_check"
    add_check_constraint :pos_tenders, "amount_cents >= 0", name: "pos_tenders_amount_non_negative"
    add_check_constraint :pos_tenders, "amount_tendered_cents IS NULL OR amount_tendered_cents >= 0",
                          name: "pos_tenders_amount_tendered_non_negative"
    add_check_constraint :pos_tenders, "change_due_cents IS NULL OR change_due_cents >= 0",
                          name: "pos_tenders_change_due_non_negative"

    # D2: pos_cash_movements (additional_float / paid_in / paid_out / safe_drop / ...).
    create_table :pos_cash_movements do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :pos_session, null: false, foreign_key: { on_delete: :restrict }
      t.references :cash_movement_type, null: false, foreign_key: { on_delete: :restrict }
      t.integer :amount_cents, null: false
      t.text :reason
      t.string :reference
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :approved_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :pos_approval, foreign_key: { on_delete: :restrict }
      t.datetime :created_at, null: false
    end

    add_check_constraint :pos_cash_movements, "amount_cents > 0", name: "pos_cash_movements_amount_positive"
  end
end
