# frozen_string_literal: true

class AddPhase4p2CashCountsAndPriceOverrideFlag < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_line_items, :price_overridden_at, :datetime
    add_column :pos_line_items, :price_overridden_by_user_id, :bigint
    add_foreign_key :pos_line_items, :users, column: :price_overridden_by_user_id, on_delete: :restrict
    add_index :pos_line_items, :price_overridden_by_user_id

    add_column :pos_sessions, :opening_cash_cents, :integer
    add_column :pos_sessions, :expected_cash_cents, :integer
    add_column :pos_sessions, :counted_cash_cents, :integer
    add_column :pos_sessions, :cash_variance_cents, :integer

    create_table :pos_session_cash_counts do |t|
      t.references :pos_session, null: false, foreign_key: { on_delete: :restrict }
      t.string :count_type, null: false
      t.integer :total_cents, null: false
      t.jsonb :denomination_detail
      t.references :counted_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :counted_at, null: false
      t.datetime :created_at, null: false
    end

    add_index :pos_session_cash_counts, [ :pos_session_id, :count_type ],
              unique: true,
              where: "count_type IN ('opening', 'closing')",
              name: "index_pos_session_cash_counts_one_opening_closing"

    add_check_constraint :pos_session_cash_counts, "total_cents >= 0",
                         name: "pos_session_cash_counts_total_non_negative"
    add_check_constraint :pos_session_cash_counts,
                         "count_type IN ('opening', 'closing', 'manager_recount', 'reconciled')",
                         name: "pos_session_cash_counts_type_check"

    add_check_constraint :pos_sessions,
                         "opening_cash_cents IS NULL OR opening_cash_cents >= 0",
                         name: "pos_sessions_opening_cash_non_negative"
    add_check_constraint :pos_sessions,
                         "counted_cash_cents IS NULL OR counted_cash_cents >= 0",
                         name: "pos_sessions_counted_cash_non_negative"
  end
end
