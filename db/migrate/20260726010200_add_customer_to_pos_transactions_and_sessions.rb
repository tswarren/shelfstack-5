# frozen_string_literal: true

class AddCustomerToPosTransactionsAndSessions < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_transactions, :customer, foreign_key: { on_delete: :restrict }

    add_reference :pos_sessions, :staged_customer, foreign_key: { to_table: :customers, on_delete: :nullify }
    add_reference :pos_sessions, :staged_customer_by_user, foreign_key: { to_table: :users, on_delete: :nullify }
    add_column :pos_sessions, :staged_customer_at, :datetime
  end
end
