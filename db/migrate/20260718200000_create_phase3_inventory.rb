# frozen_string_literal: true

class CreatePhase3Inventory < ActiveRecord::Migration[8.1]
  def change
    add_column :departments, :default_cost_estimation_margin_bps, :integer
    add_check_constraint :departments,
      "default_cost_estimation_margin_bps IS NULL OR (default_cost_estimation_margin_bps >= 0 AND default_cost_estimation_margin_bps <= 10000)",
      name: "departments_margin_bps_range"

    create_table :inventory_adjustment_reasons do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :adjustment_kind, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :requires_note, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :inventory_adjustment_reasons, [ :organization_id, :adjustment_kind, :code ],
              unique: true, name: "index_inv_adj_reasons_on_org_kind_code"
    add_check_constraint :inventory_adjustment_reasons,
      "adjustment_kind IN ('opening_inventory', 'quantity_only', 'cost_correction')",
      name: "inv_adj_reasons_kind"
    add_check_constraint :inventory_adjustment_reasons,
      "requires_note IN (TRUE, FALSE)", name: "inv_adj_reasons_requires_note_boolean"
    add_check_constraint :inventory_adjustment_reasons,
      "active IN (TRUE, FALSE)", name: "inv_adj_reasons_active_boolean"

    create_table :stock_balances do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :product_variant, null: false, foreign_key: { on_delete: :restrict }
      t.integer :on_hand, null: false, default: 0
      t.integer :reserved, null: false, default: 0
      t.integer :unavailable, null: false, default: 0
      t.bigint :inventory_value_cents, default: 0
      t.integer :moving_average_cost_cents
      t.string :cost_quality, null: false, default: "unknown"
      t.integer :last_known_unit_cost_cents
      t.string :last_known_cost_quality
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end
    add_index :stock_balances, [ :store_id, :product_variant_id ], unique: true
    add_check_constraint :stock_balances, "reserved >= 0", name: "stock_balances_reserved_nonneg"
    add_check_constraint :stock_balances, "unavailable >= 0", name: "stock_balances_unavailable_nonneg"
    add_check_constraint :stock_balances,
      "cost_quality IN ('actual', 'estimated', 'mixed', 'unknown')",
      name: "stock_balances_cost_quality"
    add_check_constraint :stock_balances,
      "last_known_cost_quality IS NULL OR last_known_cost_quality IN ('actual', 'estimated', 'mixed', 'unknown')",
      name: "stock_balances_last_known_cost_quality"
    add_check_constraint :stock_balances,
      "(on_hand > 0) OR (inventory_value_cents = 0 AND moving_average_cost_cents IS NULL)",
      name: "stock_balances_nonpositive_value_state"
    add_check_constraint :stock_balances,
      "(on_hand <> 0) OR (cost_quality = 'unknown')",
      name: "stock_balances_zero_quality_unknown"
    add_check_constraint :stock_balances,
      "(on_hand <= 0) OR (cost_quality = 'unknown' AND inventory_value_cents IS NULL) OR (cost_quality <> 'unknown' AND inventory_value_cents IS NOT NULL)",
      name: "stock_balances_positive_value_state"

    create_table :inventory_adjustments do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.string :kind, null: false
      t.string :status, null: false, default: "draft"
      t.references :inventory_adjustment_reason, null: false, foreign_key: { on_delete: :restrict }
      t.text :note
      t.string :reason_code_snapshot
      t.string :reason_name_snapshot
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :posted_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :posted_at
      t.references :cancelled_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :cancelled_at
      t.text :cancel_note
      t.string :posting_key

      t.timestamps
    end
    add_index :inventory_adjustments, :posting_key, unique: true, where: "posting_key IS NOT NULL"
    add_check_constraint :inventory_adjustments,
      "kind IN ('opening_inventory', 'quantity_only', 'cost_correction')",
      name: "inventory_adjustments_kind"
    add_check_constraint :inventory_adjustments,
      "status IN ('draft', 'posted', 'cancelled')",
      name: "inventory_adjustments_status"

    create_table :inventory_adjustment_lines do |t|
      t.references :inventory_adjustment, null: false, foreign_key: { on_delete: :restrict }
      t.references :product_variant, null: false, foreign_key: { on_delete: :restrict }
      t.integer :position, null: false, default: 0
      t.integer :quantity_delta, null: false, default: 0
      t.integer :input_unit_cost_cents
      t.string :input_cost_method
      t.string :input_cost_quality
      t.bigint :corrected_inventory_value_cents
      t.references :estimate_department, foreign_key: { to_table: :departments, on_delete: :restrict }
      t.integer :estimate_regular_price_cents
      t.integer :estimate_margin_bps
      t.integer :estimate_unit_cost_cents

      t.timestamps
    end
    add_index :inventory_adjustment_lines, [ :inventory_adjustment_id, :product_variant_id ],
              unique: true, name: "index_inv_adj_lines_on_adj_and_variant"
    add_check_constraint :inventory_adjustment_lines,
      "input_cost_method IS NULL OR input_cost_method IN ('explicit', 'configured_estimate', 'moving_average', 'unknown')",
      name: "inv_adj_lines_input_cost_method"
    add_check_constraint :inventory_adjustment_lines,
      "input_cost_quality IS NULL OR input_cost_quality IN ('actual', 'estimated', 'mixed', 'unknown')",
      name: "inv_adj_lines_input_cost_quality"

    create_table :inventory_ledger_entries do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :product_variant, null: false, foreign_key: { on_delete: :restrict }
      t.string :movement_type, null: false
      t.integer :quantity_delta, null: false
      t.bigint :inventory_value_delta_cents
      t.integer :movement_cost_cents
      t.integer :unit_cost_cents
      t.string :cost_method, null: false
      t.string :cost_quality, null: false
      t.integer :resulting_on_hand, null: false
      t.bigint :resulting_inventory_value_cents
      t.integer :resulting_moving_average_cost_cents
      t.string :resulting_cost_quality, null: false
      t.string :reason_code
      t.text :reason_note
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.references :reversal_of_entry, foreign_key: { to_table: :inventory_ledger_entries, on_delete: :restrict }
      t.references :estimate_department, foreign_key: { to_table: :departments, on_delete: :restrict }
      t.integer :estimate_regular_price_cents
      t.integer :estimate_margin_bps
      t.integer :estimate_unit_cost_cents
      t.string :posting_key, null: false
      t.references :posted_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :posted_at, null: false

      t.timestamps null: false
    end
    add_index :inventory_ledger_entries, :posting_key, unique: true
    add_index :inventory_ledger_entries, [ :source_type, :source_id ]
    add_index :inventory_ledger_entries, [ :store_id, :product_variant_id, :posted_at ]
    add_check_constraint :inventory_ledger_entries,
      "movement_type IN ('opening_inventory', 'quantity_adjustment', 'cost_correction')",
      name: "inv_ledger_movement_type"
    add_check_constraint :inventory_ledger_entries,
      "cost_method IN ('explicit', 'configured_estimate', 'moving_average', 'unknown')",
      name: "inv_ledger_cost_method"
    add_check_constraint :inventory_ledger_entries,
      "cost_quality IN ('actual', 'estimated', 'mixed', 'unknown')",
      name: "inv_ledger_cost_quality"
    add_check_constraint :inventory_ledger_entries,
      "resulting_cost_quality IN ('actual', 'estimated', 'mixed', 'unknown')",
      name: "inv_ledger_resulting_cost_quality"
    add_check_constraint :inventory_ledger_entries,
      "movement_cost_cents IS NULL OR movement_cost_cents >= 0",
      name: "inv_ledger_movement_cost_nonneg"
    add_check_constraint :inventory_ledger_entries,
      "unit_cost_cents IS NULL OR unit_cost_cents >= 0",
      name: "inv_ledger_unit_cost_nonneg"

    create_table :inventory_reservations do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :product_variant, null: false, foreign_key: { on_delete: :restrict }
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.integer :quantity, null: false
      t.string :status, null: false, default: "active"
      t.datetime :reserved_at, null: false
      t.datetime :released_at
      t.datetime :converted_at
      t.references :released_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :release_reason

      t.timestamps
    end
    add_index :inventory_reservations,
              [ :store_id, :product_variant_id, :source_type, :source_id ],
              unique: true,
              where: "status = 'active'",
              name: "index_inv_reservations_active_source_unique"
    add_index :inventory_reservations, [ :store_id, :product_variant_id, :status ]
    add_check_constraint :inventory_reservations,
      "status IN ('active', 'released', 'converted')",
      name: "inv_reservations_status"
    add_check_constraint :inventory_reservations,
      "source_type IN ('pos_line_item', 'product_request')",
      name: "inv_reservations_source_type"
    add_check_constraint :inventory_reservations,
      "quantity > 0",
      name: "inv_reservations_quantity_positive"
  end
end
