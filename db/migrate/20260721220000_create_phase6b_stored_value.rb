# frozen_string_literal: true

# Stored-value accounts. Alternate identifiers are normalized on create by
# StoredValueAccount.normalize_alternate_identifier (btrim, strip whitespace
# and hyphens, lowercase, blank → NULL) and must remain organization-unique
# under that contract. First-install seeds/app code write already-normalized
# values; no upgrade-only renormalization migration is required.
class CreatePhase6bStoredValue < ActiveRecord::Migration[8.1]
  def change
    create_table :stored_value_adjustment_reasons do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :requires_note, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :stored_value_adjustment_reasons, [ :organization_id, :code ], unique: true,
              name: "index_sv_adjustment_reasons_on_org_and_code"

    create_table :stored_value_accounts do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.string :account_type, null: false
      t.string :account_number, null: false
      t.string :alternate_identifier
      t.string :status, null: false, default: "active"
      t.bigint :current_balance_cents, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.timestamps
    end
    add_index :stored_value_accounts, :account_number, unique: true
    add_index :stored_value_accounts, [ :organization_id, :alternate_identifier ], unique: true,
              where: "alternate_identifier IS NOT NULL",
              name: "index_sv_accounts_on_org_and_alternate"
    add_check_constraint :stored_value_accounts,
                         "account_type IN ('gift_card', 'store_credit', 'trade_credit')",
                         name: "sv_accounts_type_check"
    add_check_constraint :stored_value_accounts,
                         "status IN ('active', 'suspended')",
                         name: "sv_accounts_status_check"
    add_check_constraint :stored_value_accounts,
                         "current_balance_cents >= 0",
                         name: "sv_accounts_balance_nonneg"

    create_table :stored_value_entries do |t|
      t.references :stored_value_account, null: false, foreign_key: { on_delete: :restrict }
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.string :entry_type, null: false
      t.bigint :amount_cents, null: false
      t.references :pos_transaction, foreign_key: { on_delete: :restrict }
      t.references :pos_line_item, foreign_key: { on_delete: :restrict }
      t.references :pos_tender, foreign_key: { on_delete: :restrict }
      t.references :reverses_entry, foreign_key: { to_table: :stored_value_entries, on_delete: :restrict }
      t.references :stored_value_adjustment_reason, foreign_key: { on_delete: :restrict }
      t.text :description
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :pos_approval, foreign_key: { on_delete: :restrict }
      t.string :posting_key, null: false
      t.datetime :created_at, null: false
    end
    add_index :stored_value_entries, :posting_key, unique: true
    add_index :stored_value_entries, :reverses_entry_id, unique: true,
              where: "reverses_entry_id IS NOT NULL",
              name: "index_sv_entries_reverses_unique"
    add_check_constraint :stored_value_entries,
                         "entry_type IN ('issued', 'reloaded', 'redeemed', 'refunded', 'manual_adjustment', 'reversal')",
                         name: "sv_entries_type_check"
    add_check_constraint :stored_value_entries,
                         "amount_cents <> 0",
                         name: "sv_entries_amount_nonzero"

    remove_check_constraint :pos_approvals, name: "pos_approvals_action_type_check"
    add_check_constraint :pos_approvals,
                         "action_type IN ('price_override', 'discount_apply', 'tax_exemption', 'tax_category_override', 'cash_movement', 'post_void', 'stored_value_adjustment')",
                         name: "pos_approvals_action_type_check"
  end
end
