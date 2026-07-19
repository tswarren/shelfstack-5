# frozen_string_literal: true

class AddCashMovementApprovalActionType < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :pos_approvals, name: "pos_approvals_action_type_check"
    add_check_constraint :pos_approvals,
                          "action_type IN ('price_override', 'discount_apply', 'tax_exemption', " \
                          "'tax_category_override', 'cash_movement')",
                          name: "pos_approvals_action_type_check"
  end
end
