# frozen_string_literal: true

class CreatePhase4eLinkedReturns < ActiveRecord::Migration[8.1]
  def change
    change_table :pos_line_items, bulk: true do |t|
      t.string :direction, null: false, default: "sale"
      t.bigint :original_pos_line_item_id
      t.bigint :return_reason_id
      t.string :return_disposition
      t.string :return_source
    end

    add_index :pos_line_items, :original_pos_line_item_id
    add_index :pos_line_items, :return_reason_id
    add_foreign_key :pos_line_items, :pos_line_items, column: :original_pos_line_item_id, on_delete: :restrict
    add_foreign_key :pos_line_items, :return_reasons, on_delete: :restrict

    add_check_constraint :pos_line_items,
                         "direction IN ('sale', 'return')",
                         name: "pos_line_items_direction_check"
    add_check_constraint :pos_line_items,
                         "direction = 'sale' OR (original_pos_line_item_id IS NOT NULL AND return_reason_id IS NOT NULL AND return_disposition IS NOT NULL)",
                         name: "pos_line_items_return_requires_link"
    add_check_constraint :pos_line_items,
                         "return_disposition IS NULL OR return_disposition IN ('return_to_stock', 'inspection_required', 'damaged', 'return_to_vendor', 'discard', 'non_inventory')",
                         name: "pos_line_items_return_disposition_check"

    remove_check_constraint :inventory_ledger_entries, name: "inv_ledger_movement_type"
    add_check_constraint :inventory_ledger_entries,
                         "movement_type IN ('opening_inventory', 'quantity_adjustment', 'cost_correction', 'sale', 'customer_return')",
                         name: "inv_ledger_movement_type"
  end
end
