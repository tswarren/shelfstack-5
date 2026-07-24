# frozen_string_literal: true

class CreatePosSessionZReports < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_session_z_reports do |t|
      t.references :pos_session, null: false, foreign_key: true, index: { unique: true }
      t.references :store, null: false, foreign_key: true
      t.bigint :z_number, null: false
      t.date :business_date, null: false
      t.datetime :source_cutoff_at, null: false
      t.string :report_definition_version, null: false
      t.datetime :generated_at, null: false
      t.references :generated_by_user, null: false, foreign_key: { to_table: :users }
      t.jsonb :payload, null: false, default: {}
      t.integer :expected_cash_cents
      t.integer :counted_cash_cents
      t.integer :cash_variance_cents
      t.timestamps null: false
    end

    add_index :pos_session_z_reports, [ :store_id, :z_number ], unique: true,
              name: "index_pos_session_z_reports_on_store_id_and_z_number"
  end
end
