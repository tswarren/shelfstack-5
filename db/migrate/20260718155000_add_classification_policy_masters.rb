# frozen_string_literal: true

# Completes classification masters when 20260718150000 ran an earlier partial version.
class AddClassificationPolicyMasters < ActiveRecord::Migration[8.1]
  def up
    unless table_exists?(:return_policies)
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
    end

    unless table_exists?(:return_reasons)
      create_table :return_reasons do |t|
        t.references :organization, null: false, foreign_key: { on_delete: :restrict }
        t.string :name, null: false
        t.string :code, null: false
        t.string :default_return_disposition
        t.boolean :active, null: false, default: true

        t.timestamps
      end
      add_index :return_reasons, [ :organization_id, :code ], unique: true
    end

    unless table_exists?(:discount_reasons)
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
    end

    unless column_exists?(:departments, :default_return_policy_id)
      add_reference :departments, :default_return_policy,
                    foreign_key: { to_table: :return_policies, on_delete: :restrict }
    end

    if column_exists?(:departments, :department_number) &&
       columns(:departments).find { |c| c.name == "department_number" }.sql_type != "integer"
      change_column :departments, :department_number, :integer, using: "department_number::integer"
    end

    if column_exists?(:departments, :maximum_merchandise_discount) &&
       columns(:departments).find { |c| c.name == "maximum_merchandise_discount" }.sql_type == "integer"
      change_column :departments, :maximum_merchandise_discount, :decimal, precision: 8, scale: 4
    end

    unless column_exists?(:merchandise_classes, :position)
      add_column :merchandise_classes, :position, :integer
    end

    change_column_null :merchandise_classes, :default_department_id, true if column_exists?(:merchandise_classes, :default_department_id)

    change_column_null :product_formats, :short_code, false if column_exists?(:product_formats, :short_code)
    change_column_null :product_formats, :format_family, false if column_exists?(:product_formats, :format_family)
    change_column_null :product_formats, :default_inventory_tracking_mode, false if column_exists?(:product_formats, :default_inventory_tracking_mode)

    remove_index :tax_categories, [ :organization_id, :name ], if_exists: true

    add_index :merchandise_classes, [ :organization_id, :parent_id ], if_not_exists: true

    add_check_constraint :departments, "postable IN (TRUE, FALSE)", name: "departments_postable_boolean", if_not_exists: true
    add_check_constraint :merchandise_classes, "level IN ('primary', 'secondary', 'minor')",
                         name: "merchandise_classes_level_check", if_not_exists: true
    add_check_constraint :product_formats,
                         "default_inventory_tracking_mode IN ('quantity', 'individual', 'none')",
                         name: "product_formats_tracking_mode_check", if_not_exists: true
  end

  def down
    # Conditional creates in #up mean this migration may not own the policy tables.
    # Dropping them here would destroy objects from 20260718150000.
    raise ActiveRecord::IrreversibleMigration
  end
end
