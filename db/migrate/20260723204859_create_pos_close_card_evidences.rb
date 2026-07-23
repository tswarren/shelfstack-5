# frozen_string_literal: true

class CreatePosCloseCardEvidences < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_close_card_evidences do |t|
      t.references :store, null: false, foreign_key: true
      t.references :pos_session, null: true, foreign_key: true
      t.references :business_day, null: true, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false
      t.string :precision
      t.integer :received_cents
      t.integer :refunded_cents
      t.integer :net_cents
      t.integer :received_count
      t.integer :refunded_count
      t.string :terminal_reference
      t.string :batch_reference
      t.text :unavailable_reason
      t.references :entered_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :entered_at, null: false
      t.timestamps null: false
    end

    add_check_constraint :pos_close_card_evidences,
                         "kind IN ('merchant_slip', 'machine_batch')",
                         name: "pos_close_card_evidences_kind_check"
    add_check_constraint :pos_close_card_evidences,
                         "status IN ('recorded', 'unavailable')",
                         name: "pos_close_card_evidences_status_check"
    add_check_constraint :pos_close_card_evidences,
                         "precision IS NULL OR precision IN ('net_only', 'received_and_refunded')",
                         name: "pos_close_card_evidences_precision_check"
    add_check_constraint :pos_close_card_evidences,
                         "((pos_session_id IS NOT NULL AND business_day_id IS NULL) OR (pos_session_id IS NULL AND business_day_id IS NOT NULL))",
                         name: "pos_close_card_evidences_exactly_one_scope"
    add_check_constraint :pos_close_card_evidences,
                         "(status = 'unavailable' AND precision IS NULL AND received_cents IS NULL AND refunded_cents IS NULL AND net_cents IS NULL AND unavailable_reason IS NOT NULL) OR (status = 'recorded' AND precision IS NOT NULL AND unavailable_reason IS NULL)",
                         name: "pos_close_card_evidences_status_shape"
    add_check_constraint :pos_close_card_evidences,
                         "status <> 'recorded' OR (precision = 'net_only' AND net_cents IS NOT NULL) OR (precision = 'received_and_refunded' AND received_cents IS NOT NULL AND refunded_cents IS NOT NULL AND net_cents IS NOT NULL)",
                         name: "pos_close_card_evidences_recorded_amounts"
  end
end
