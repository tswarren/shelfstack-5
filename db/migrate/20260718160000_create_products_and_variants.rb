# frozen_string_literal: true

class CreateProductsAndVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :identifier, null: false
      t.string :alternate_identifier
      t.boolean :identifier_generated, null: false, default: false
      t.string :identifier_validation_status, null: false, default: "valid"
      t.text :identifier_warning
      t.string :name, null: false
      t.string :subtitle
      t.text :description
      t.string :product_type
      t.references :product_format, foreign_key: true
      t.references :merchandise_class, foreign_key: true
      t.references :default_department, foreign_key: { to_table: :departments }
      t.references :default_tax_category, foreign_key: { to_table: :tax_categories }
      t.string :variant_structure, null: false, default: "single"
      t.integer :list_price_cents
      t.string :status, null: false, default: "active"
      t.boolean :sellable, null: false, default: false
      t.date :available_from
      t.date :available_until
      t.string :publisher_or_manufacturer_name
      t.string :imprint_or_brand_name
      t.timestamps
    end
    add_index :products, %i[organization_id identifier], unique: true
    add_index :products, :alternate_identifier

    add_check_constraint :products,
                         "variant_structure = 'single'",
                         name: "products_variant_structure_single"
    add_check_constraint :products,
                         "list_price_cents IS NULL OR list_price_cents >= 0",
                         name: "products_list_price_cents_non_negative"
    add_check_constraint :products,
                         "identifier_validation_status IN ('valid', 'warning', 'invalid', 'not_applicable')",
                         name: "products_identifier_validation_status_check"
    add_check_constraint :products,
                         "status IN ('active', 'inactive', 'discontinued')",
                         name: "products_status_check"

    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :name, null: false
      t.text :description
      t.string :inventory_tracking_mode, null: false, default: "quantity"
      t.references :default_product_condition, foreign_key: { to_table: :product_conditions }
      t.integer :regular_price_cents
      t.references :department, foreign_key: true
      t.references :tax_category, foreign_key: true
      t.references :merchandise_class, foreign_key: true
      t.bigint :return_policy_id
      t.string :discountability_setting
      t.string :returnability_setting
      t.string :status, null: false, default: "active"
      t.boolean :sellable, null: false, default: true
      t.boolean :purchasable, null: false, default: true
      t.date :available_from
      t.date :available_until
      t.timestamps
    end
    add_index :product_variants, :sku, unique: true

    add_check_constraint :product_variants,
                         "inventory_tracking_mode IN ('quantity', 'individual', 'none')",
                         name: "product_variants_inventory_tracking_mode_check"
    add_check_constraint :product_variants,
                         "regular_price_cents IS NULL OR regular_price_cents >= 0",
                         name: "product_variants_regular_price_cents_non_negative"
    add_check_constraint :product_variants,
                         "status IN ('active', 'inactive', 'discontinued')",
                         name: "product_variants_status_check"
  end
end
