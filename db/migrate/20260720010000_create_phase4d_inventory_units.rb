# frozen_string_literal: true

class CreatePhase4dInventoryUnits < ActiveRecord::Migration[8.1]
  def change
    # ADR-0001/ADR-0002: one Inventory Unit per exact physical copy of an
    # individually tracked Product Variant, carrying its own generated `27`
    # Unit Identifier and exact acquisition cost.
    create_table :inventory_units do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :product_variant, null: false, foreign_key: { on_delete: :restrict }
      t.string :unit_identifier, null: false
      t.string :status, null: false, default: "available"
      t.references :product_condition, foreign_key: { on_delete: :restrict }
      t.integer :acquisition_cost_cents
      t.integer :unit_price_cents
      t.string :acquisition_source
      t.datetime :acquired_at, null: false
      t.text :notes
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :sold_at

      t.timestamps
    end

    add_index :inventory_units, :unit_identifier, unique: true
    add_index :inventory_units, [ :store_id, :product_variant_id, :status ]
    add_check_constraint :inventory_units, "status IN ('available', 'reserved', 'sold')",
                          name: "inventory_units_status_check"
    add_check_constraint :inventory_units, "acquisition_cost_cents IS NULL OR acquisition_cost_cents >= 0",
                          name: "inventory_units_acquisition_cost_non_negative"
    add_check_constraint :inventory_units, "unit_price_cents IS NULL OR unit_price_cents >= 0",
                          name: "inventory_units_unit_price_non_negative"

    # Reservation and POS-line FKs to the exact Unit (ADR-0006: "an individually
    # tracked reservation identifies the exact inventory unit"; "one inventory
    # unit may have no more than one active reservation").
    add_reference :inventory_reservations, :inventory_unit, foreign_key: { on_delete: :restrict }
    add_index :inventory_reservations, :inventory_unit_id, unique: true, where: "status = 'active'",
              name: "index_inv_reservations_active_unit_unique"
    add_check_constraint :inventory_reservations, "inventory_unit_id IS NULL OR quantity = 1",
                          name: "inv_reservations_unit_quantity_one"

    add_reference :pos_line_items, :inventory_unit, foreign_key: { on_delete: :restrict }
    add_check_constraint :pos_line_items, "inventory_unit_id IS NULL OR quantity = 1",
                          name: "pos_line_items_unit_quantity_one"
  end
end
