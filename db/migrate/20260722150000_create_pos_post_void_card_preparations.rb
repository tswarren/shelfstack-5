# frozen_string_literal: true

# Transaction-level post-void plan (approved before terminal use) plus per-card
# durable confirmations. recorded_orphan retains late auth after abandon.
class CreatePosPostVoidCardPreparations < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_post_void_preparations, id: :uuid do |t|
      t.references :original_pos_transaction, null: false, foreign_key: { to_table: :pos_transactions }
      t.references :store, null: false, foreign_key: true
      t.references :prepared_by_user, null: false, foreign_key: { to_table: :users }
      t.references :pos_approval, null: false, foreign_key: true
      t.references :abandoned_by_user, foreign_key: { to_table: :users }
      t.references :consumed_by_user, foreign_key: { to_table: :users }

      t.text :reason, null: false
      t.string :status, null: false, default: "approved"
      t.jsonb :commercial_snapshot, null: false, default: {}
      t.string :commercial_fingerprint, null: false
      t.integer :fingerprint_version, null: false, default: 1

      t.datetime :abandoned_at
      t.datetime :consumed_at

      t.timestamps
    end

    add_index :pos_post_void_preparations, :original_pos_transaction_id,
              unique: true,
              where: "status = 'approved'",
              name: "index_pos_post_void_preps_one_approved_per_txn"
    add_index :pos_post_void_preparations, :pos_approval_id,
              unique: true,
              name: "index_pos_post_void_preps_on_pos_approval_unique"
    add_index :pos_post_void_preparations, :status

    add_check_constraint :pos_post_void_preparations,
                         "status IN ('approved', 'consumed', 'abandoned')",
                         name: "pos_post_void_preps_status_check"
    add_check_constraint :pos_post_void_preparations, <<~SQL.squish,
      (status = 'approved' AND abandoned_at IS NULL AND consumed_at IS NULL)
      OR (status = 'consumed' AND consumed_at IS NOT NULL AND abandoned_at IS NULL)
      OR (status = 'abandoned' AND abandoned_at IS NOT NULL AND consumed_at IS NULL)
    SQL
                         name: "pos_post_void_preps_state_shape"

    create_table :pos_post_void_card_preparations, id: :uuid do |t|
      t.references :pos_post_void_preparation, null: false, type: :uuid,
                   foreign_key: true, index: true
      t.references :original_pos_transaction, null: false, foreign_key: { to_table: :pos_transactions }
      t.references :original_pos_tender, null: false, foreign_key: { to_table: :pos_tenders }
      t.references :store, null: false, foreign_key: true
      t.references :prepared_by_user, null: false, foreign_key: { to_table: :users }
      t.references :recorded_by_user, foreign_key: { to_table: :users }
      t.references :abandoned_by_user, foreign_key: { to_table: :users }
      t.references :consumed_by_user, foreign_key: { to_table: :users }
      t.references :correcting_pos_transaction, foreign_key: { to_table: :pos_transactions }

      t.integer :amount_cents, null: false
      t.string :status, null: false, default: "prepared"

      t.datetime :expires_at, null: false
      t.datetime :abandoned_at
      t.datetime :consumed_at

      t.string :authorization_code
      t.string :terminal_reference
      t.string :external_void_reference
      t.datetime :authorized_at

      t.timestamps
    end

    add_index :pos_post_void_card_preparations,
              [ :original_pos_transaction_id, :original_pos_tender_id ],
              unique: true,
              where: "status IN ('prepared', 'recorded')",
              name: "index_pos_post_void_card_preps_one_active_per_tender"
    add_index :pos_post_void_card_preparations, :status,
              where: "status = 'recorded' AND consumed_at IS NULL",
              name: "index_pos_post_void_card_preps_unresolved_recorded"
    add_index :pos_post_void_card_preparations, :status,
              where: "status = 'recorded_orphan'",
              name: "index_pos_post_void_card_preps_orphans"

    add_check_constraint :pos_post_void_card_preparations, "amount_cents > 0",
                         name: "pos_post_void_card_preps_amount_positive"
    add_check_constraint :pos_post_void_card_preparations,
                         "status IN ('prepared', 'recorded', 'consumed', 'abandoned', 'recorded_orphan')",
                         name: "pos_post_void_card_preps_status_check"
    add_check_constraint :pos_post_void_card_preparations, <<~SQL.squish,
      (status = 'prepared' AND authorization_code IS NULL AND authorized_at IS NULL
        AND abandoned_at IS NULL AND consumed_at IS NULL)
      OR (status = 'recorded' AND authorization_code IS NOT NULL AND authorized_at IS NOT NULL
        AND abandoned_at IS NULL AND consumed_at IS NULL)
      OR (status = 'consumed' AND authorization_code IS NOT NULL AND authorized_at IS NOT NULL
        AND consumed_at IS NOT NULL AND abandoned_at IS NULL)
      OR (status = 'abandoned' AND abandoned_at IS NOT NULL AND authorization_code IS NULL
        AND consumed_at IS NULL)
      OR (status = 'recorded_orphan' AND authorization_code IS NOT NULL AND authorized_at IS NOT NULL
        AND consumed_at IS NULL)
    SQL
                         name: "pos_post_void_card_preps_state_shape"
  end
end
