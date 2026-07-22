# frozen_string_literal: true

# Links a replacement card-refund preparation to the reconciliation tender it
# will displace. Capacity math excludes that tender while the replacement is prepared/recorded.
class AddReplacesPosTenderToCardRefundPreparations < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_card_refund_preparations, :replaces_pos_tender,
                  foreign_key: { to_table: :pos_tenders },
                  index: false

    add_index :pos_card_refund_preparations, :replaces_pos_tender_id,
              unique: true,
              where: "replaces_pos_tender_id IS NOT NULL AND status IN ('prepared', 'recorded_tender') AND resolved_at IS NULL",
              name: "index_pos_card_refund_preps_one_active_replacement"
  end
end
