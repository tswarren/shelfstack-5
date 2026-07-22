# frozen_string_literal: true

class CreatePosCardRefundPreparations < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_card_refund_preparations, id: :uuid do |t|
      t.references :pos_transaction, null: false, foreign_key: true
      t.references :tender_type, null: false, foreign_key: true
      t.references :intended_original_pos_tender, foreign_key: { to_table: :pos_tenders }
      t.references :pos_approval, foreign_key: true
      t.references :pos_tender, foreign_key: true
      t.references :prepared_by_user, null: false, foreign_key: { to_table: :users }
      t.references :recorded_by_user, foreign_key: { to_table: :users }
      t.references :abandoned_by_user, foreign_key: { to_table: :users }
      t.references :resolved_by_user, foreign_key: { to_table: :users }
      t.references :correcting_pos_transaction, foreign_key: { to_table: :pos_transactions }

      t.integer :amount_cents, null: false
      t.jsonb :plan_snapshot, null: false, default: {}
      t.string :plan_fingerprint, null: false
      t.integer :fingerprint_version, null: false, default: 1

      t.string :status, null: false, default: "prepared"
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.datetime :abandoned_at

      t.string :authorization_code
      t.string :terminal_reference
      t.datetime :authorized_at

      t.boolean :requires_reconciliation, null: false, default: false
      t.jsonb :reconciliation_reasons, null: false, default: []

      t.string :resolution_kind
      t.datetime :resolved_at
      t.text :resolution_reason
      t.string :external_void_reference

      t.timestamps
    end

    add_index :pos_card_refund_preparations, [ :pos_transaction_id, :status ],
              name: "index_pos_card_refund_preps_on_txn_and_status"
    add_index :pos_card_refund_preparations, :pos_tender_id,
              unique: true,
              where: "pos_tender_id IS NOT NULL",
              name: "index_pos_card_refund_preps_on_pos_tender_unique"
    add_index :pos_card_refund_preparations, :pos_approval_id,
              unique: true,
              where: "pos_approval_id IS NOT NULL",
              name: "index_pos_card_refund_preps_on_pos_approval_unique"
    add_index :pos_card_refund_preparations, :status,
              where: "status = 'recorded_orphan' AND resolved_at IS NULL",
              name: "index_pos_card_refund_preps_unresolved_orphans"

    add_check_constraint :pos_card_refund_preparations, "amount_cents > 0",
                         name: "pos_card_refund_preps_amount_positive"
    add_check_constraint :pos_card_refund_preparations,
                         "status IN ('prepared', 'recorded_tender', 'recorded_orphan', 'abandoned')",
                         name: "pos_card_refund_preps_status_check"
    add_check_constraint :pos_card_refund_preparations, <<~SQL.squish,
      (status = 'prepared' AND authorization_code IS NULL AND consumed_at IS NULL
        AND pos_tender_id IS NULL AND abandoned_at IS NULL)
      OR (status = 'recorded_tender' AND authorization_code IS NOT NULL AND consumed_at IS NOT NULL
        AND pos_tender_id IS NOT NULL AND abandoned_at IS NULL)
      OR (status = 'recorded_orphan' AND authorization_code IS NOT NULL AND consumed_at IS NOT NULL
        AND pos_tender_id IS NULL AND abandoned_at IS NULL)
      OR (status = 'abandoned' AND abandoned_at IS NOT NULL AND authorization_code IS NULL
        AND pos_tender_id IS NULL AND consumed_at IS NULL)
    SQL
                         name: "pos_card_refund_preps_state_shape"
    add_check_constraint :pos_card_refund_preparations, <<~SQL.squish,
      resolution_kind IS NULL OR resolution_kind IN (
        'externally_voided', 'validated_and_accepted', 'replaced',
        'external_void_confirmed', 'linked_to_correcting_transaction',
        'accepted_financial_exception'
      )
    SQL
                         name: "pos_card_refund_preps_resolution_kind_check"
  end
end
