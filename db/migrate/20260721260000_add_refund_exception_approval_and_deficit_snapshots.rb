# frozen_string_literal: true

class AddRefundExceptionApprovalAndDeficitSnapshots < ActiveRecord::Migration[8.1]
  def change
    change_table :pos_tenders, bulk: true do |t|
      t.references :pos_approval, foreign_key: { to_table: :pos_approvals, on_delete: :restrict }, null: true
    end

    change_table :inventory_ledger_entries, bulk: true do |t|
      t.bigint :prior_open_provisional_deficit_cost_cents
      t.bigint :resulting_open_provisional_deficit_cost_cents
      t.string :prior_deficit_cost_quality
      t.string :resulting_deficit_cost_quality
    end

    add_check_constraint :inventory_ledger_entries,
                         "prior_deficit_cost_quality IS NULL OR (prior_deficit_cost_quality::text = ANY (ARRAY['actual'::character varying, 'estimated'::character varying, 'mixed'::character varying, 'unknown'::character varying]::text[]))",
                         name: "inv_ledger_prior_deficit_quality_check"
    add_check_constraint :inventory_ledger_entries,
                         "resulting_deficit_cost_quality IS NULL OR (resulting_deficit_cost_quality::text = ANY (ARRAY['actual'::character varying, 'estimated'::character varying, 'mixed'::character varying, 'unknown'::character varying]::text[]))",
                         name: "inv_ledger_resulting_deficit_quality_check"

    add_index :stored_value_entries, :stored_value_account_id,
              unique: true,
              where: "entry_type = 'issued'",
              name: "index_sv_entries_one_issued_per_account"
  end
end
