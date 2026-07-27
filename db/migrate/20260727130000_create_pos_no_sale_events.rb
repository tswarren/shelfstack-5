# frozen_string_literal: true

class CreatePosNoSaleEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_no_sale_events do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :pos_session, null: false, foreign_key: { on_delete: :restrict }
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :reason, null: false, limit: 255
      t.datetime :occurred_at, null: false
      t.string :idempotency_key, null: false
      t.timestamps
    end

    add_index :pos_no_sale_events, :idempotency_key, unique: true
    add_check_constraint :pos_no_sale_events, "char_length(btrim(reason)) > 0",
                         name: "pos_no_sale_events_reason_present"
  end
end
