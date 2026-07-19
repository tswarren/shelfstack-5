# frozen_string_literal: true

class CreatePhase4bPosCommercial < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_line_items, :tax_category_overridden_at, :datetime
    add_reference :pos_line_items, :tax_category_overridden_by_user, foreign_key: { to_table: :users, on_delete: :restrict }
    add_column :pos_line_items, :tax_category_override_reason, :text
    add_reference :pos_line_items, :original_tax_category, foreign_key: { to_table: :tax_categories, on_delete: :restrict }

    create_table :pos_discounts do |t|
      t.references :pos_transaction, null: false, foreign_key: { on_delete: :restrict }
      t.references :target_pos_line_item, foreign_key: { to_table: :pos_line_items, on_delete: :restrict }
      t.string :scope, null: false
      t.string :method, null: false
      t.string :tax_treatment, null: false, default: "reduces_taxable_base"
      t.integer :position, null: false, default: 0
      t.integer :base_amount_cents
      t.integer :rate_bps
      t.integer :requested_amount_cents
      t.integer :applied_amount_cents, null: false
      t.references :discount_reason, foreign_key: { on_delete: :restrict }
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :created_at, null: false
    end

    add_check_constraint :pos_discounts, "scope IN ('line', 'transaction')", name: "pos_discounts_scope_check"
    add_check_constraint :pos_discounts, "method IN ('percentage', 'fixed_amount', 'fixed_price')",
                          name: "pos_discounts_method_check"
    add_check_constraint :pos_discounts,
                          "tax_treatment IN ('reduces_taxable_base', 'does_not_reduce_taxable_base')",
                          name: "pos_discounts_tax_treatment_check"
    add_check_constraint :pos_discounts,
                          "(scope = 'line' AND target_pos_line_item_id IS NOT NULL) OR (scope = 'transaction' AND target_pos_line_item_id IS NULL)",
                          name: "pos_discounts_target_matches_scope"
    add_check_constraint :pos_discounts, "applied_amount_cents >= 0", name: "pos_discounts_applied_amount_non_negative"
    add_check_constraint :pos_discounts, "base_amount_cents IS NULL OR base_amount_cents >= 0",
                          name: "pos_discounts_base_amount_non_negative"
    add_check_constraint :pos_discounts, "rate_bps IS NULL OR rate_bps >= 0", name: "pos_discounts_rate_bps_non_negative"
    add_check_constraint :pos_discounts, "requested_amount_cents IS NULL OR requested_amount_cents >= 0",
                          name: "pos_discounts_requested_amount_non_negative"

    create_table :pos_discount_allocations do |t|
      t.references :pos_discount, null: false, foreign_key: { on_delete: :restrict }
      t.references :pos_line_item, null: false, foreign_key: { on_delete: :restrict }
      t.integer :eligible_amount_cents
      t.integer :allocated_amount_cents, null: false
      t.datetime :created_at, null: false
    end

    add_index :pos_discount_allocations, [ :pos_discount_id, :pos_line_item_id ], unique: true,
              name: "index_pos_discount_allocations_on_discount_and_line"
    add_check_constraint :pos_discount_allocations, "allocated_amount_cents >= 0",
                          name: "pos_discount_allocations_amount_non_negative"
    add_check_constraint :pos_discount_allocations, "eligible_amount_cents IS NULL OR eligible_amount_cents >= 0",
                          name: "pos_discount_allocations_eligible_non_negative"

    create_table :pos_line_item_taxes do |t|
      t.references :pos_line_item, null: false, foreign_key: { on_delete: :restrict }
      t.references :store_tax_rule, null: false, foreign_key: { on_delete: :restrict }
      t.references :store_tax_rate, foreign_key: { on_delete: :restrict }
      t.references :tax_category, null: false, foreign_key: { on_delete: :restrict }
      t.string :treatment_snapshot, null: false
      t.string :receipt_code_snapshot
      t.integer :position, null: false, default: 0
      t.integer :taxable_amount_cents, null: false, default: 0
      t.decimal :taxable_fraction_snapshot, precision: 10, scale: 8, null: false
      t.decimal :rate, precision: 10, scale: 8
      t.boolean :compounds_on_prior_tax_snapshot, null: false, default: false
      t.integer :amount_cents, null: false, default: 0
      t.datetime :created_at, null: false
    end

    add_check_constraint :pos_line_item_taxes, "treatment_snapshot IN ('taxable', 'zero_rated', 'exempt')",
                          name: "pos_line_item_taxes_treatment_check"
    add_check_constraint :pos_line_item_taxes, "taxable_amount_cents >= 0",
                          name: "pos_line_item_taxes_taxable_amount_non_negative"
    add_check_constraint :pos_line_item_taxes, "amount_cents >= 0", name: "pos_line_item_taxes_amount_non_negative"

    create_table :pos_tax_exemptions do |t|
      t.references :pos_transaction, null: false, foreign_key: { on_delete: :restrict }
      t.string :coverage, null: false, default: "whole_transaction"
      t.string :exemption_type, null: false
      t.text :notes
      t.references :created_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.timestamps
    end

    add_index :pos_tax_exemptions, :pos_transaction_id, unique: true,
              name: "index_pos_tax_exemptions_one_per_transaction"
    add_check_constraint :pos_tax_exemptions, "coverage = 'whole_transaction'", name: "pos_tax_exemptions_coverage_check"

    create_table :pos_approvals do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :pos_session, foreign_key: { on_delete: :restrict }
      t.references :pos_transaction, foreign_key: { on_delete: :restrict }
      t.references :pos_line_item, foreign_key: { on_delete: :restrict }
      t.string :action_type, null: false
      t.references :requested_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :approved_by_user, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :reason, null: false
      t.decimal :requested_value, precision: 18, scale: 8
      t.decimal :approved_value, precision: 18, scale: 8
      t.decimal :authorization_limit_snapshot, precision: 18, scale: 8
      t.datetime :approved_at, null: false
      t.datetime :created_at, null: false
    end

    add_check_constraint :pos_approvals,
                          "action_type IN ('price_override', 'discount_apply', 'tax_exemption', 'tax_category_override')",
                          name: "pos_approvals_action_type_check"
  end
end
