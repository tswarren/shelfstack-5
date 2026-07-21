# frozen_string_literal: true

# OD-007: a Customer Request may hold several individually tracked Inventory
# Units at once. The previous unique index on (store, variant, source) blocked
# that for every reservation shape. Keep one active quantity reservation per
# source, but allow multiple active unit reservations for the same request.
class AllowMultipleUnitReservationsPerRequest < ActiveRecord::Migration[8.1]
  def up
    remove_index :inventory_reservations, name: "index_inv_reservations_active_source_unique"

    add_index :inventory_reservations,
              [ :store_id, :product_variant_id, :source_type, :source_id ],
              unique: true,
              where: "status = 'active' AND inventory_unit_id IS NULL",
              name: "index_inv_reservations_active_qty_source_unique"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "cannot recreate the active-source unique index while multiple active " \
          "unit reservations may exist for the same product request"
  end
end
