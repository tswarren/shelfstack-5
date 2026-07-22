# frozen_string_literal: true

class AddResolutionPosApprovalToCardRefundPreparations < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_card_refund_preparations, :resolution_pos_approval,
                  foreign_key: { to_table: :pos_approvals },
                  null: true,
                  index: { unique: true, where: "resolution_pos_approval_id IS NOT NULL",
                           name: "index_pos_card_refund_preps_on_resolution_approval_unique" }
  end
end
