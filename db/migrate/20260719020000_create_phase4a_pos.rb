# frozen_string_literal: true

class CreatePhase4aPos < ActiveRecord::Migration[8.1]
  def change
    create_table :business_days do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.date :reporting_date, null: false
      t.string :status, null: false, default: "open"
      t.datetime :opened_at, null: false
      t.references :opened_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :closed_at
      t.references :closed_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.timestamps
    end

    add_index :business_days, [ :store_id ], unique: true, where: "status = 'open'",
              name: "index_business_days_one_open_per_store"
    add_check_constraint :business_days, "status IN ('open', 'closed')", name: "business_days_status_check"

    create_table :pos_sessions do |t|
      t.references :business_day, null: false, foreign_key: { on_delete: :restrict }
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :pos_device, null: false, foreign_key: { on_delete: :restrict }
      t.references :cash_drawer, foreign_key: { on_delete: :restrict }
      t.references :cashier_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :status, null: false, default: "open"
      t.datetime :opened_at, null: false
      t.references :opened_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :closed_at
      t.references :closed_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.timestamps
    end

    add_index :pos_sessions, [ :pos_device_id ], unique: true, where: "status = 'open'",
              name: "index_pos_sessions_one_open_per_device"
    add_index :pos_sessions, [ :cash_drawer_id ], unique: true,
              where: "status = 'open' AND cash_drawer_id IS NOT NULL",
              name: "index_pos_sessions_one_active_per_drawer"
    add_check_constraint :pos_sessions, "status IN ('open', 'closed')", name: "pos_sessions_status_check"

    create_table :pos_transactions do |t|
      t.string :public_id, null: false
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :origin_pos_session, null: false, foreign_key: { to_table: :pos_sessions, on_delete: :restrict }
      t.references :active_pos_session, foreign_key: { to_table: :pos_sessions, on_delete: :restrict }
      t.references :cashier_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :status, null: false, default: "open"
      t.datetime :opened_at, null: false
      t.datetime :suspended_at
      t.datetime :recalled_at
      t.datetime :cancelled_at
      t.references :cancelled_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :cancel_reason
      t.timestamps
    end

    add_index :pos_transactions, :public_id, unique: true
    add_check_constraint :pos_transactions, "status IN ('open', 'suspended', 'completed', 'cancelled')",
                          name: "pos_transactions_status_check"

    create_table :pos_line_items do |t|
      t.references :pos_transaction, null: false, foreign_key: { on_delete: :restrict }
      t.string :line_kind, null: false
      t.string :status, null: false, default: "pending"
      t.references :product_variant, foreign_key: { on_delete: :restrict }
      t.references :department, null: false, foreign_key: { on_delete: :restrict }
      t.references :tax_category, foreign_key: { on_delete: :restrict }
      t.string :description_snapshot
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false
      t.integer :position, null: false, default: 0
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :removed_at
      t.references :removed_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :remove_reason
      t.timestamps
    end

    add_check_constraint :pos_line_items, "line_kind IN ('product', 'open_ring')", name: "pos_line_items_line_kind_check"
    add_check_constraint :pos_line_items, "status IN ('pending', 'completed', 'removed')",
                          name: "pos_line_items_status_check"
    add_check_constraint :pos_line_items, "quantity > 0", name: "pos_line_items_quantity_positive"
    add_check_constraint :pos_line_items, "unit_price_cents >= 0", name: "pos_line_items_unit_price_non_negative"
    add_check_constraint :pos_line_items,
                          "(line_kind = 'product' AND product_variant_id IS NOT NULL) OR " \
                          "(line_kind = 'open_ring' AND product_variant_id IS NULL)",
                          name: "pos_line_items_product_variant_matches_kind"
  end
end
