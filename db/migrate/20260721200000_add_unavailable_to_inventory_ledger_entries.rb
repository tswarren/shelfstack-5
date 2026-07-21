# frozen_string_literal: true

class AddUnavailableToInventoryLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    change_table :inventory_ledger_entries, bulk: true do |t|
      t.integer :unavailable_delta, null: false, default: 0
      t.integer :resulting_unavailable
      t.string :availability_reason
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE inventory_ledger_entries
          SET resulting_unavailable = 0
          WHERE resulting_unavailable IS NULL
        SQL
        change_column_null :inventory_ledger_entries, :resulting_unavailable, false
      end
      dir.down do
        change_column_null :inventory_ledger_entries, :resulting_unavailable, true
      end
    end

    add_index :inventory_ledger_entries, :reversal_of_entry_id,
              unique: true,
              where: "reversal_of_entry_id IS NOT NULL",
              name: "index_inv_ledger_reversal_of_entry_id_unique"
  end
end
