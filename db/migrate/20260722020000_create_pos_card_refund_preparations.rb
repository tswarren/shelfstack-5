# frozen_string_literal: true

# Durable card-refund preparations (final first-install shape).
# Correcting-transaction linkage is deferred; financial-exception resolution
# approvals use resolution_pos_approval_id (separate from prepare-time
# pos_approval_id).
class CreatePosCardRefundPreparations < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_card_refund_preparations, id: :uuid do |t|
      t.references :pos_transaction, null: false, foreign_key: true
      t.references :tender_type, null: false, foreign_key: true
      t.references :intended_original_pos_tender, foreign_key: { to_table: :pos_tenders }
      t.references :replaces_pos_tender, foreign_key: { to_table: :pos_tenders }, index: false
      t.references :pos_approval, foreign_key: true
      t.references :resolution_pos_approval, foreign_key: { to_table: :pos_approvals }, index: false
      t.references :pos_tender, foreign_key: true
      t.references :prepared_by_user, null: false, foreign_key: { to_table: :users }
      t.references :recorded_by_user, foreign_key: { to_table: :users }
      t.references :abandoned_by_user, foreign_key: { to_table: :users }
      t.references :resolved_by_user, foreign_key: { to_table: :users }

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
    add_index :pos_card_refund_preparations, :resolution_pos_approval_id,
              unique: true,
              where: "resolution_pos_approval_id IS NOT NULL",
              name: "index_pos_card_refund_preps_on_resolution_approval_unique"
    add_index :pos_card_refund_preparations, :status,
              where: "status = 'recorded_orphan' AND resolved_at IS NULL",
              name: "index_pos_card_refund_preps_unresolved_orphans"
    add_index :pos_card_refund_preparations, :replaces_pos_tender_id,
              unique: true,
              where: "replaces_pos_tender_id IS NOT NULL AND status IN ('prepared', 'recorded_tender') AND resolved_at IS NULL",
              name: "index_pos_card_refund_preps_one_active_replacement"

    add_check_constraint :pos_card_refund_preparations, "amount_cents > 0",
                         name: "pos_card_refund_preps_amount_positive"
    add_check_constraint :pos_card_refund_preparations,
                         "status IN ('prepared', 'recorded_tender', 'recorded_orphan', 'abandoned')",
                         name: "pos_card_refund_preps_status_check"
    # recorded_orphan may retain abandoned_* when auth arrives after abandon.
    add_check_constraint :pos_card_refund_preparations, <<~SQL.squish,
      (status = 'prepared' AND authorization_code IS NULL AND consumed_at IS NULL
        AND pos_tender_id IS NULL AND abandoned_at IS NULL)
      OR (status = 'recorded_tender' AND authorization_code IS NOT NULL AND consumed_at IS NOT NULL
        AND pos_tender_id IS NOT NULL AND abandoned_at IS NULL)
      OR (status = 'recorded_orphan' AND authorization_code IS NOT NULL AND consumed_at IS NOT NULL
        AND pos_tender_id IS NULL)
      OR (status = 'abandoned' AND abandoned_at IS NOT NULL AND authorization_code IS NULL
        AND pos_tender_id IS NULL AND consumed_at IS NULL)
    SQL
                         name: "pos_card_refund_preps_state_shape"
    add_check_constraint :pos_card_refund_preparations, <<~SQL.squish,
      resolution_kind IS NULL OR resolution_kind IN (
        'externally_voided', 'validated_and_accepted', 'replaced',
        'external_void_confirmed', 'accepted_financial_exception'
      )
    SQL
                         name: "pos_card_refund_preps_resolution_kind_check"

    # Approval action type used by reconciliation financial-exception acceptance.
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          ALTER TABLE pos_approvals
          DROP CONSTRAINT pos_approvals_action_type_check
        SQL
        execute <<~SQL.squish
          ALTER TABLE pos_approvals
          ADD CONSTRAINT pos_approvals_action_type_check
          CHECK (action_type::text = ANY (ARRAY[
            'price_override'::character varying,
            'discount_apply'::character varying,
            'tax_exemption'::character varying,
            'tax_category_override'::character varying,
            'cash_movement'::character varying,
            'post_void'::character varying,
            'stored_value_adjustment'::character varying,
            'stored_value_refund_exception'::character varying,
            'card_refund_reconciliation'::character varying
          ]::text[]))
        SQL
      end
      dir.down do
        execute <<~SQL.squish
          ALTER TABLE pos_approvals
          DROP CONSTRAINT pos_approvals_action_type_check
        SQL
        execute <<~SQL.squish
          ALTER TABLE pos_approvals
          ADD CONSTRAINT pos_approvals_action_type_check
          CHECK (action_type::text = ANY (ARRAY[
            'price_override'::character varying,
            'discount_apply'::character varying,
            'tax_exemption'::character varying,
            'tax_category_override'::character varying,
            'cash_movement'::character varying,
            'post_void'::character varying,
            'stored_value_adjustment'::character varying,
            'stored_value_refund_exception'::character varying
          ]::text[]))
        SQL
      end
    end
  end
end
