# frozen_string_literal: true

class AddNotApplicableStoreTaxRuleTreatment < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :store_tax_rules, name: "store_tax_rules_treatment_check"
    remove_check_constraint :store_tax_rules, name: "store_tax_rules_rate_required_unless_exempt"

    add_check_constraint :store_tax_rules,
                          "treatment IN ('taxable', 'zero_rated', 'exempt', 'not_applicable')",
                          name: "store_tax_rules_treatment_check"
    add_check_constraint :store_tax_rules,
                          "(treatment IN ('taxable', 'zero_rated') AND store_tax_rate_id IS NOT NULL) OR " \
                          "(treatment IN ('exempt', 'not_applicable'))",
                          name: "store_tax_rules_rate_required_unless_non_collecting"
  end

  def down
    remove_check_constraint :store_tax_rules, name: "store_tax_rules_treatment_check"
    remove_check_constraint :store_tax_rules, name: "store_tax_rules_rate_required_unless_non_collecting"

    execute <<~SQL.squish
      UPDATE store_tax_rules SET treatment = 'exempt' WHERE treatment = 'not_applicable'
    SQL

    add_check_constraint :store_tax_rules,
                          "treatment IN ('taxable', 'zero_rated', 'exempt')",
                          name: "store_tax_rules_treatment_check"
    add_check_constraint :store_tax_rules,
                          "(treatment IN ('taxable', 'zero_rated') AND store_tax_rate_id IS NOT NULL) OR " \
                          "(treatment = 'exempt')",
                          name: "store_tax_rules_rate_required_unless_exempt"
  end
end
