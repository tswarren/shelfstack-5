# frozen_string_literal: true

class CreatePhase5bPurchaseOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :stores, :next_purchase_order_number, :bigint, null: false, default: 1
    add_check_constraint :stores, "next_purchase_order_number >= 1",
      name: "stores_next_purchase_order_number_positive"

    create_table :purchase_orders do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :vendor, null: false, foreign_key: { on_delete: :restrict }
      t.string :purchase_order_number, null: false
      t.string :status, null: false, default: "draft"
      t.date :ordered_on
      t.date :expected_on
      t.string :currency_code, limit: 3, null: false
      t.datetime :ordered_at
      t.references :ordered_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :buyer_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :vendor_reference
      t.text :notes
      t.datetime :cancelled_at
      t.references :cancelled_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :closed_at
      t.references :closed_by_user, foreign_key: { to_table: :users, on_delete: :restrict }

      t.timestamps
    end

    add_index :purchase_orders, [ :store_id, :purchase_order_number ], unique: true,
      name: "index_purchase_orders_on_store_and_number"
    add_check_constraint :purchase_orders,
      "status IN ('draft', 'ordered', 'closed', 'cancelled')",
      name: "purchase_orders_status_check"

    create_table :purchase_order_lines do |t|
      t.references :purchase_order, null: false, foreign_key: { on_delete: :restrict }
      t.integer :position, null: false, default: 0
      t.references :product_variant, null: false, foreign_key: { on_delete: :restrict }
      t.references :product_variant_vendor, foreign_key: { on_delete: :restrict }
      t.string :description_snapshot
      t.string :identifier_snapshot
      t.string :sku_snapshot
      t.string :vendor_item_code_snapshot
      t.integer :ordered_quantity, null: false
      t.integer :cancelled_quantity, null: false, default: 0
      t.integer :received_quantity, null: false, default: 0
      t.string :cost_entry_method, null: false
      t.integer :list_cost_cents
      t.integer :discount_bps
      t.integer :expected_unit_cost_cents, null: false
      t.integer :expected_extended_cost_cents
      t.string :cost_provenance
      t.boolean :returnable_snapshot
      t.text :notes

      t.timestamps
    end

    add_check_constraint :purchase_order_lines,
      "cost_entry_method IN ('discount_from_list', 'direct_net_cost')",
      name: "po_lines_cost_entry_method_check"
    add_check_constraint :purchase_order_lines, "ordered_quantity > 0",
      name: "po_lines_ordered_quantity_positive"
    add_check_constraint :purchase_order_lines, "cancelled_quantity >= 0",
      name: "po_lines_cancelled_quantity_nonneg"
    add_check_constraint :purchase_order_lines, "cancelled_quantity <= ordered_quantity",
      name: "po_lines_cancelled_quantity_within_ordered"
    add_check_constraint :purchase_order_lines, "received_quantity >= 0",
      name: "po_lines_received_quantity_nonneg"
    add_check_constraint :purchase_order_lines, "expected_unit_cost_cents >= 0",
      name: "po_lines_expected_unit_cost_nonneg"
    add_check_constraint :purchase_order_lines,
      "expected_extended_cost_cents IS NULL OR expected_extended_cost_cents >= 0",
      name: "po_lines_expected_extended_cost_nonneg"
    add_check_constraint :purchase_order_lines, "list_cost_cents IS NULL OR list_cost_cents >= 0",
      name: "po_lines_list_cost_nonneg"
    add_check_constraint :purchase_order_lines,
      "discount_bps IS NULL OR (discount_bps >= 0 AND discount_bps <= 10000)",
      name: "po_lines_discount_bps_range"
  end
end
