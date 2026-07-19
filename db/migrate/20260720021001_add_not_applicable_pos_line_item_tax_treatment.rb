# frozen_string_literal: true

class AddNotApplicablePosLineItemTaxTreatment < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :pos_line_item_taxes, name: "pos_line_item_taxes_treatment_check"
    add_check_constraint :pos_line_item_taxes,
                          "treatment_snapshot IN ('taxable', 'zero_rated', 'exempt', 'not_applicable')",
                          name: "pos_line_item_taxes_treatment_check"
  end

  def down
    execute <<~SQL.squish
      UPDATE pos_line_item_taxes
      SET treatment_snapshot = 'exempt'
      WHERE treatment_snapshot = 'not_applicable'
    SQL

    remove_check_constraint :pos_line_item_taxes, name: "pos_line_item_taxes_treatment_check"
    add_check_constraint :pos_line_item_taxes,
                          "treatment_snapshot IN ('taxable', 'zero_rated', 'exempt')",
                          name: "pos_line_item_taxes_treatment_check"
  end
end
