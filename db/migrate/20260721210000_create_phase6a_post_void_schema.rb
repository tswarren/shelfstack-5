# frozen_string_literal: true

class CreatePhase6aPostVoidSchema < ActiveRecord::Migration[8.1]
  def change
    change_table :pos_transactions, bulk: true do |t|
      t.references :reverses_pos_transaction, foreign_key: { to_table: :pos_transactions, on_delete: :restrict }
      t.text :post_void_reason
      t.references :post_void_pos_approval, foreign_key: { to_table: :pos_approvals, on_delete: :restrict }
    end

    add_index :pos_transactions, :reverses_pos_transaction_id,
              unique: true,
              where: "reverses_pos_transaction_id IS NOT NULL",
              name: "index_pos_transactions_reverses_unique"

    add_reference :pos_line_items, :reverses_pos_line_item,
                  foreign_key: { to_table: :pos_line_items, on_delete: :restrict }
    add_index :pos_line_items, :reverses_pos_line_item_id,
              unique: true,
              where: "reverses_pos_line_item_id IS NOT NULL",
              name: "index_pos_line_items_reverses_unique"

    change_table :pos_tenders, bulk: true do |t|
      t.references :reverses_pos_tender, foreign_key: { to_table: :pos_tenders, on_delete: :restrict }
      t.references :original_pos_tender, foreign_key: { to_table: :pos_tenders, on_delete: :restrict }
    end
    add_index :pos_tenders, :reverses_pos_tender_id,
              unique: true,
              where: "reverses_pos_tender_id IS NOT NULL",
              name: "index_pos_tenders_reverses_unique"

    remove_check_constraint :pos_approvals, name: "pos_approvals_action_type_check"
    add_check_constraint :pos_approvals,
                         "action_type IN ('price_override', 'discount_apply', 'tax_exemption', 'tax_category_override', 'cash_movement', 'post_void')",
                         name: "pos_approvals_action_type_check"
  end
end
