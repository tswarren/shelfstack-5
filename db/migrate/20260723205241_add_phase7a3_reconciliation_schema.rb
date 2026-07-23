# frozen_string_literal: true

class AddPhase7a3ReconciliationSchema < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_sessions, :reconciled_by_user, foreign_key: { to_table: :users }, null: true
    add_column :pos_sessions, :reconciled_at, :datetime, null: true

    add_reference :business_days, :reconciled_by_user, foreign_key: { to_table: :users }, null: true
    add_column :business_days, :reconciled_at, :datetime, null: true

    create_table :reconciliations do |t|
      t.references :store, null: false, foreign_key: true
      t.references :pos_session, null: true, foreign_key: true, index: { unique: true }
      t.references :business_day, null: true, foreign_key: true, index: { unique: true }
      t.string :scope_type, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :opened_at, null: false
      t.references :opened_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :reconciled_at
      t.references :reconciled_by_user, null: true, foreign_key: { to_table: :users }
      t.timestamps null: false
    end

    add_check_constraint :reconciliations,
                         "scope_type IN ('session', 'business_day')",
                         name: "reconciliations_scope_type_check"
    add_check_constraint :reconciliations,
                         "status IN ('draft', 'finalized')",
                         name: "reconciliations_status_check"
    add_check_constraint :reconciliations,
                         "((scope_type = 'session' AND pos_session_id IS NOT NULL AND business_day_id IS NULL) OR (scope_type = 'business_day' AND business_day_id IS NOT NULL AND pos_session_id IS NULL))",
                         name: "reconciliations_scope_shape"
    add_check_constraint :reconciliations,
                         "(status = 'draft' AND reconciled_at IS NULL AND reconciled_by_user_id IS NULL) OR (status = 'finalized' AND reconciled_at IS NOT NULL AND reconciled_by_user_id IS NOT NULL)",
                         name: "reconciliations_finalize_shape"

    create_table :reconciliation_comparisons do |t|
      t.references :reconciliation, null: false, foreign_key: true
      t.string :comparison_type, null: false
      t.string :precision
      t.integer :expected_cents
      t.integer :expected_received_cents
      t.integer :expected_refunded_cents
      t.integer :observed_cents
      t.integer :observed_received_cents
      t.integer :observed_refunded_cents
      t.boolean :observed_unavailable, null: false, default: false
      t.integer :variance_cents
      t.string :external_reference
      t.references :pos_close_card_evidence, null: true, foreign_key: true
      t.integer :position, null: false, default: 1
      t.timestamps null: false
    end

    add_check_constraint :reconciliation_comparisons,
                         "comparison_type IN ('session_cash', 'session_merchant_slip', 'day_machine_batch')",
                         name: "reconciliation_comparisons_type_check"
    add_check_constraint :reconciliation_comparisons,
                         "precision IS NULL OR precision IN ('net_only', 'received_and_refunded')",
                         name: "reconciliation_comparisons_precision_check"
    add_check_constraint :reconciliation_comparisons,
                         "(observed_unavailable = TRUE AND observed_cents IS NULL AND observed_received_cents IS NULL AND observed_refunded_cents IS NULL AND variance_cents IS NULL) OR (observed_unavailable = FALSE)",
                         name: "reconciliation_comparisons_unavailable_shape"
    add_index :reconciliation_comparisons, [ :reconciliation_id, :position ],
              unique: true, name: "index_recon_comparisons_on_recon_and_position"

    create_table :reconciliation_findings do |t|
      t.references :reconciliation_comparison, null: false, foreign_key: true
      t.string :category, null: false
      t.text :explanation, null: false
      t.references :recorded_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :recorded_at, null: false
      t.timestamps null: false
    end

    create_table :reconciliation_resolutions do |t|
      t.references :reconciliation, null: false, foreign_key: true
      t.references :reconciliation_comparison, null: true, foreign_key: true
      t.string :resolution_type, null: false
      t.text :explanation
      t.string :linked_correction_type
      t.bigint :linked_correction_id
      t.references :supersedes_resolution, null: true, foreign_key: { to_table: :reconciliation_resolutions }
      t.boolean :superseded, null: false, default: false
      t.references :recorded_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :recorded_at, null: false
      t.timestamps null: false
    end

    add_check_constraint :reconciliation_resolutions,
                         "resolution_type IN ('explained_no_correction', 'accepted_variance', 'linked_domain_correction', 'unresolved', 'accept_evidence_unavailable')",
                         name: "reconciliation_resolutions_type_check"
  end
end
