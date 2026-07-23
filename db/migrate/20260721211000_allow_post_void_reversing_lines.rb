# frozen_string_literal: true

class AllowPostVoidReversingLines < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :pos_line_items, name: "pos_line_items_return_requires_link"
    add_check_constraint :pos_line_items, <<~SQL.squish, name: "pos_line_items_return_requires_link"
      direction::text = 'sale'::text
      OR reverses_pos_line_item_id IS NOT NULL
      OR (
        original_pos_line_item_id IS NOT NULL
        AND return_reason_id IS NOT NULL
        AND return_disposition IS NOT NULL
      )
    SQL
  end
end
