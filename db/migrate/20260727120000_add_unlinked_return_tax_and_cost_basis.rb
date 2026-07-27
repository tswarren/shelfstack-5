# frozen_string_literal: true

class AddUnlinkedReturnTaxAndCostBasis < ActiveRecord::Migration[8.1]
  def change
    change_column_null :pos_line_item_taxes, :store_tax_rule_id, true

    change_table :pos_line_items, bulk: true do |t|
      t.string :tax_basis_snapshot
      t.integer :explicit_tax_amount_cents
      t.bigint :tax_basis_confirmed_by_user_id
      t.datetime :tax_basis_confirmed_at

      t.string :cost_basis_type_snapshot
      t.string :cost_basis_source_snapshot
      t.integer :cost_proposed_unit_cents
      t.integer :cost_confirmed_unit_cents
      t.bigint :cost_confirmed_by_user_id
      t.datetime :cost_confirmed_at
    end

    add_foreign_key :pos_line_items, :users, column: :tax_basis_confirmed_by_user_id, on_delete: :nullify
    add_foreign_key :pos_line_items, :users, column: :cost_confirmed_by_user_id, on_delete: :nullify

    add_check_constraint :pos_line_items,
      "tax_basis_snapshot IS NULL OR (tax_basis_snapshot IN ('current_configured_rules', 'external_receipt_tax', 'no_tax_refund'))",
      name: "pos_line_items_tax_basis_snapshot_check"
    add_check_constraint :pos_line_items,
      "explicit_tax_amount_cents IS NULL OR explicit_tax_amount_cents >= 0",
      name: "pos_line_items_explicit_tax_amount_non_negative"
    add_check_constraint :pos_line_items,
      "cost_basis_type_snapshot IS NULL OR (cost_basis_type_snapshot IN ('moving_average', 'configured_estimate'))",
      name: "pos_line_items_cost_basis_type_check"
    add_check_constraint :pos_line_items,
      "cost_proposed_unit_cents IS NULL OR cost_proposed_unit_cents >= 0",
      name: "pos_line_items_cost_proposed_unit_non_negative"
    add_check_constraint :pos_line_items,
      "cost_confirmed_unit_cents IS NULL OR cost_confirmed_unit_cents >= 0",
      name: "pos_line_items_cost_confirmed_unit_non_negative"
  end
end
