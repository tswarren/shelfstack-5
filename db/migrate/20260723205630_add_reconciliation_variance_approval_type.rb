# frozen_string_literal: true

class AddReconciliationVarianceApprovalType < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :pos_approvals, name: "pos_approvals_action_type_check"
    add_check_constraint :pos_approvals,
                         "action_type IN ('price_override', 'discount_apply', 'tax_exemption', 'tax_category_override', 'cash_movement', 'post_void', 'stored_value_adjustment', 'stored_value_refund_exception', 'card_refund_reconciliation', 'reconciliation_variance')",
                         name: "pos_approvals_action_type_check"
  end

  def down
    remove_check_constraint :pos_approvals, name: "pos_approvals_action_type_check"
    add_check_constraint :pos_approvals,
                         "action_type IN ('price_override', 'discount_apply', 'tax_exemption', 'tax_category_override', 'cash_movement', 'post_void', 'stored_value_adjustment', 'stored_value_refund_exception', 'card_refund_reconciliation')",
                         name: "pos_approvals_action_type_check"
  end
end
