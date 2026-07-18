# frozen_string_literal: true

class CreateAccessControlAndAudit < ActiveRecord::Migration[8.1]
  def change
    create_table :permissions do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :permission_group
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :permissions, :code, unique: true

    create_table :roles do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :system_template, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :roles, [ :organization_id, :code ], unique: true
    add_index :roles, [ :organization_id, :name ], unique: true

    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: { on_delete: :restrict }
      t.references :permission, null: false, foreign_key: { on_delete: :restrict }

      t.timestamps
    end
    add_index :role_permissions, [ :role_id, :permission_id ], unique: true

    create_table :store_memberships do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :role, null: false, foreign_key: { on_delete: :restrict }
      t.boolean :active, null: false, default: true
      t.date :starts_on
      t.date :ends_on
      t.decimal :maximum_discount_rate, precision: 10, scale: 8
      t.integer :maximum_discount_amount_cents
      t.decimal :maximum_price_override_rate, precision: 10, scale: 8
      t.integer :maximum_cash_refund_cents
      t.integer :maximum_no_receipt_return_cents
      t.integer :maximum_paid_out_cents
      t.integer :cash_variance_review_threshold_cents
      t.references :assigned_by_user, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end
    add_index :store_memberships, [ :user_id, :store_id ], unique: true

    add_check_constraint :store_memberships,
      "starts_on IS NULL OR ends_on IS NULL OR starts_on <= ends_on",
      name: "store_memberships_starts_on_before_ends_on"
    add_check_constraint :store_memberships,
      "maximum_discount_amount_cents IS NULL OR maximum_discount_amount_cents >= 0",
      name: "store_memberships_discount_amount_non_negative"
    add_check_constraint :store_memberships,
      "maximum_cash_refund_cents IS NULL OR maximum_cash_refund_cents >= 0",
      name: "store_memberships_cash_refund_non_negative"
    add_check_constraint :store_memberships,
      "maximum_no_receipt_return_cents IS NULL OR maximum_no_receipt_return_cents >= 0",
      name: "store_memberships_no_receipt_return_non_negative"
    add_check_constraint :store_memberships,
      "maximum_paid_out_cents IS NULL OR maximum_paid_out_cents >= 0",
      name: "store_memberships_paid_out_non_negative"
    add_check_constraint :store_memberships,
      "cash_variance_review_threshold_cents IS NULL OR cash_variance_review_threshold_cents >= 0",
      name: "store_memberships_cash_variance_non_negative"
    add_check_constraint :store_memberships,
      "maximum_discount_rate IS NULL OR (maximum_discount_rate >= 0 AND maximum_discount_rate <= 1)",
      name: "store_memberships_discount_rate_range"
    add_check_constraint :store_memberships,
      "maximum_price_override_rate IS NULL OR (maximum_price_override_rate >= 0 AND maximum_price_override_rate <= 1)",
      name: "store_memberships_price_override_rate_range"

    create_table :pos_devices do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.string :code, null: false
      t.string :name, null: false
      t.string :device_type, null: false, default: "register"
      t.boolean :active, null: false, default: true
      t.datetime :last_seen_at

      t.timestamps
    end
    add_index :pos_devices, [ :store_id, :code ], unique: true

    create_table :cash_drawers do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :cash_drawers, [ :store_id, :code ], unique: true

    create_table :administrative_audit_events do |t|
      t.references :actor_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.references :store, foreign_key: { on_delete: :restrict }
      t.string :action, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end
    add_index :administrative_audit_events, [ :subject_type, :subject_id ]
    add_index :administrative_audit_events, :created_at
  end
end
