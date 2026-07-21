# frozen_string_literal: true

class AddPhase6cStoredValueLines < ActiveRecord::Migration[8.1]
  def up
    change_column_null :pos_line_items, :department_id, true

    add_reference :pos_line_items, :stored_value_account, foreign_key: { on_delete: :restrict }
    add_column :pos_line_items, :stored_value_operation, :string
    add_column :pos_line_items, :stored_value_account_type_snapshot, :string
    add_column :pos_line_items, :stored_value_account_number_snapshot, :string

    remove_check_constraint :pos_line_items, name: "pos_line_items_line_kind_check"
    add_check_constraint :pos_line_items,
                         "line_kind IN ('product', 'open_ring', 'stored_value')",
                         name: "pos_line_items_line_kind_check"

    remove_check_constraint :pos_line_items, name: "pos_line_items_product_variant_matches_kind"
    add_check_constraint :pos_line_items, <<~SQL.squish, name: "pos_line_items_product_variant_matches_kind"
      (line_kind = 'product' AND product_variant_id IS NOT NULL)
      OR (line_kind = 'open_ring' AND product_variant_id IS NULL)
      OR (line_kind = 'stored_value' AND product_variant_id IS NULL AND inventory_unit_id IS NULL
          AND tax_category_id IS NULL AND department_id IS NULL
          AND stored_value_account_id IS NOT NULL
          AND stored_value_operation IN ('issue', 'reload')
          AND quantity = 1 AND direction = 'sale')
    SQL

    add_check_constraint :pos_line_items, <<~SQL.squish, name: "pos_line_items_department_matches_kind"
      (line_kind IN ('product', 'open_ring') AND department_id IS NOT NULL)
      OR (line_kind = 'stored_value' AND department_id IS NULL)
    SQL
  end

  def down
    remove_check_constraint :pos_line_items, name: "pos_line_items_department_matches_kind"
    remove_check_constraint :pos_line_items, name: "pos_line_items_product_variant_matches_kind"
    remove_check_constraint :pos_line_items, name: "pos_line_items_line_kind_check"

    add_check_constraint :pos_line_items,
                         "line_kind IN ('product', 'open_ring')",
                         name: "pos_line_items_line_kind_check"
    add_check_constraint :pos_line_items,
                         "line_kind = 'product' AND product_variant_id IS NOT NULL OR line_kind = 'open_ring' AND product_variant_id IS NULL",
                         name: "pos_line_items_product_variant_matches_kind"

    remove_column :pos_line_items, :stored_value_account_number_snapshot
    remove_column :pos_line_items, :stored_value_account_type_snapshot
    remove_column :pos_line_items, :stored_value_operation
    remove_reference :pos_line_items, :stored_value_account, foreign_key: true

    execute <<~SQL
      UPDATE pos_line_items SET department_id = (
        SELECT id FROM departments LIMIT 1
      ) WHERE department_id IS NULL
    SQL
    change_column_null :pos_line_items, :department_id, false
  end
end
