# frozen_string_literal: true

class AddPhase7a1StoreReportingColumns < ActiveRecord::Migration[8.1]
  def change
    change_table :stores, bulk: true do |t|
      t.string :card_reconciliation_grain, null: false, default: "business_day"
      t.bigint :next_session_z_number, null: false, default: 1
      t.bigint :next_business_day_z_number, null: false, default: 1
    end

    add_check_constraint :stores,
                         "card_reconciliation_grain IN ('business_day', 'session')",
                         name: "stores_card_reconciliation_grain_check"
    add_check_constraint :stores,
                         "next_session_z_number >= 1",
                         name: "stores_next_session_z_number_positive"
    add_check_constraint :stores,
                         "next_business_day_z_number >= 1",
                         name: "stores_next_business_day_z_number_positive"
  end
end
