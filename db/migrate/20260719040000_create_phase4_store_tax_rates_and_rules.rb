# frozen_string_literal: true

class CreatePhase4StoreTaxRatesAndRules < ActiveRecord::Migration[8.1]
  def change
    create_table :store_tax_rates do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.string :code, null: false
      t.string :name, null: false
      t.string :receipt_code, limit: 3
      t.string :jurisdiction_name
      t.decimal :rate, precision: 10, scale: 8, null: false
      t.date :effective_from
      t.date :effective_to
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :store_tax_rates, [ :store_id, :code ], unique: true
    add_check_constraint :store_tax_rates, "rate >= 0", name: "store_tax_rates_rate_non_negative"
    add_check_constraint :store_tax_rates,
                          "effective_from IS NULL OR effective_to IS NULL OR effective_from <= effective_to",
                          name: "store_tax_rates_effective_period_order"

    create_table :store_tax_rules do |t|
      t.references :store, null: false, foreign_key: { on_delete: :restrict }
      t.references :tax_category, null: false, foreign_key: { on_delete: :restrict }
      t.references :store_tax_rate, foreign_key: { on_delete: :restrict }
      t.string :component_code, null: false
      t.string :treatment, null: false
      t.decimal :taxable_fraction, precision: 10, scale: 8, null: false, default: 1
      t.integer :calculation_order, null: false, default: 0, limit: 2
      t.boolean :compounds_on_prior_tax, null: false, default: false
      t.date :effective_from
      t.date :effective_to
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :store_tax_rules, [ :store_id, :tax_category_id, :component_code ],
              name: "index_store_tax_rules_on_store_category_component"
    add_check_constraint :store_tax_rules, "treatment IN ('taxable', 'zero_rated', 'exempt')",
                          name: "store_tax_rules_treatment_check"
    add_check_constraint :store_tax_rules,
                          "(treatment IN ('taxable', 'zero_rated') AND store_tax_rate_id IS NOT NULL) OR " \
                          "(treatment = 'exempt')",
                          name: "store_tax_rules_rate_required_unless_exempt"
    add_check_constraint :store_tax_rules, "taxable_fraction >= 0 AND taxable_fraction <= 1",
                          name: "store_tax_rules_taxable_fraction_range"
    add_check_constraint :store_tax_rules, "calculation_order >= 0",
                          name: "store_tax_rules_calculation_order_non_negative"
    add_check_constraint :store_tax_rules,
                          "effective_from IS NULL OR effective_to IS NULL OR effective_from <= effective_to",
                          name: "store_tax_rules_effective_period_order"
  end
end
