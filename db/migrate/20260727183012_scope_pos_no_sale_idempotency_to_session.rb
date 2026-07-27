# frozen_string_literal: true

class ScopePosNoSaleIdempotencyToSession < ActiveRecord::Migration[8.1]
  def change
    remove_index :pos_no_sale_events, :idempotency_key
    add_index :pos_no_sale_events, %i[pos_session_id idempotency_key], unique: true,
              name: "index_pos_no_sale_events_on_session_and_idempotency_key"
  end
end
