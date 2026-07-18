# frozen_string_literal: true

class CreateClassificationMasters < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_categories do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :tax_categories, [ :organization_id, :code ], unique: true

    create_table :return_policies do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :final_sale, null: false, default: false
      t.integer :return_window_days
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :return_policies, [ :organization_id, :code ], unique: true

    create_table :return_reasons do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, null: false
      t.string :code, null: false
      t.string :default_return_disposition
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :return_reasons, [ :organization_id, :code ], unique: true

    create_table :discount_reasons do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, null: false
      t.string :code, null: false
      t.string :default_calculation_method, null: false
      t.integer :default_rate_bps
      t.integer :default_amount_cents
      t.integer :maximum_rate_bps
      t.boolean :requires_approval, null: false, default: true
      t.references :resulting_return_policy, foreign_key: { to_table: :return_policies, on_delete: :nullify }
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :discount_reasons, [ :organization_id, :code ], unique: true

    create_table :departments do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.references :parent_department, foreign_key: { to_table: :departments, on_delete: :restrict }
      t.integer :department_number, null: false
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :postable, null: false, default: true
      t.string :inventory_asset_gl_account_code, limit: 20
      t.string :sales_revenue_gl_account_code, limit: 20
      t.string :sales_returns_gl_account_code, limit: 20
      t.string :sales_discounts_gl_account_code, limit: 20
      t.string :cogs_gl_account_code, limit: 20
      t.string :vendor_returns_gl_account_code, limit: 20
      t.string :inventory_shrinkage_gl_account_code, limit: 20
      t.string :inventory_write_down_gl_account_code, limit: 20
      t.string :inventory_adjustment_gl_account_code, limit: 20
      t.string :freight_in_gl_account_code, limit: 20
      t.references :default_tax_category, foreign_key: { to_table: :tax_categories, on_delete: :restrict }
      t.decimal :maximum_merchandise_discount, precision: 8, scale: 4
      t.references :default_return_policy, foreign_key: { to_table: :return_policies, on_delete: :restrict }
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :departments, [ :organization_id, :code ], unique: true
    add_index :departments, [ :organization_id, :department_number ], unique: true
    add_check_constraint :departments,
                         "postable IN (TRUE, FALSE)",
                         name: "departments_postable_boolean"

    create_table :merchandise_classes do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.references :parent, foreign_key: { to_table: :merchandise_classes, on_delete: :restrict }
      t.string :code, null: false
      t.string :name, null: false
      t.string :level, null: false
      t.text :description
      t.integer :position
      t.references :default_department, foreign_key: { to_table: :departments, on_delete: :restrict }
      t.references :default_used_department, foreign_key: { to_table: :departments, on_delete: :restrict }
      t.string :default_inventory_tracking_mode
      t.string :default_discountability
      t.string :default_returnability
      t.references :default_tax_category, foreign_key: { to_table: :tax_categories, on_delete: :restrict }
      t.text :shelving_guidance
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :merchandise_classes, [ :organization_id, :code ], unique: true
    add_index :merchandise_classes, [ :organization_id, :parent_id ]
    add_check_constraint :merchandise_classes,
                         "level IN ('primary', 'secondary', 'minor')",
                         name: "merchandise_classes_level_check"

    create_table :product_formats do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, null: false
      t.string :code, null: false
      t.string :short_code, limit: 2, null: false
      t.string :format_family, null: false
      t.string :default_inventory_tracking_mode, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :product_formats, [ :organization_id, :code ], unique: true
    add_index :product_formats, [ :organization_id, :short_code ], unique: true
    add_check_constraint :product_formats,
                         "default_inventory_tracking_mode IN ('quantity', 'individual', 'none')",
                         name: "product_formats_tracking_mode_check"

    create_table :product_conditions do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :product_conditions, [ :organization_id, :code ], unique: true
  end
end
