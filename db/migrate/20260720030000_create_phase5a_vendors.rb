# frozen_string_literal: true

class CreatePhase5aVendors < ActiveRecord::Migration[8.1]
  def change
    create_table :vendors do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :legal_name
      t.boolean :active, null: false, default: true
      t.string :ordering_contact
      t.string :ordering_email
      t.string :phone
      t.string :account_reference
      t.integer :default_supplier_discount_bps
      t.text :notes

      t.timestamps
    end

    add_index :vendors, %i[organization_id code], unique: true

    create_table :product_variant_vendors do |t|
      t.references :product_variant, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: true
      t.string :vendor_item_code
      t.string :vendor_identifier
      t.integer :list_cost_cents
      t.integer :discount_bps
      t.integer :expected_unit_cost_cents
      t.integer :minimum_order_quantity
      t.integer :order_multiple
      t.boolean :returnable
      t.boolean :preferred, null: false, default: false
      t.boolean :active, null: false, default: true
      t.datetime :last_ordered_at
      t.datetime :last_received_at
      t.text :notes

      t.timestamps
    end

    add_index :product_variant_vendors, %i[product_variant_id vendor_id], unique: true,
              name: "index_product_variant_vendors_on_variant_and_vendor"
  end
end
