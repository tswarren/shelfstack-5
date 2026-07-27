# frozen_string_literal: true

class AddUnlinkedReturnPracticalChecks < ActiveRecord::Migration[8.1]
  def change
    # external_receipt_tax requires an explicit nonnegative tax amount.
    add_check_constraint :pos_line_items,
      "(tax_basis_snapshot IS DISTINCT FROM 'external_receipt_tax') OR " \
      "(explicit_tax_amount_cents IS NOT NULL AND explicit_tax_amount_cents >= 0)",
      name: "pos_line_items_external_tax_requires_amount"

    # Tax basis confirmation actor and timestamp travel together.
    add_check_constraint :pos_line_items,
      "(tax_basis_snapshot IS NULL) OR " \
      "(tax_basis_confirmed_by_user_id IS NOT NULL AND tax_basis_confirmed_at IS NOT NULL)",
      name: "pos_line_items_tax_basis_confirmation_complete"

    # Inventory cost confirmation actor/time/amount travel together when present.
    add_check_constraint :pos_line_items,
      "(cost_confirmed_unit_cents IS NULL AND cost_confirmed_by_user_id IS NULL AND cost_confirmed_at IS NULL) OR " \
      "(cost_confirmed_unit_cents IS NOT NULL AND cost_confirmed_by_user_id IS NOT NULL AND cost_confirmed_at IS NOT NULL)",
      name: "pos_line_items_cost_confirmation_complete"
  end
end
