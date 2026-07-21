# frozen_string_literal: true

class AddPhase6dStoredValueTenders < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_tenders, :stored_value_account, foreign_key: { on_delete: :restrict }
  end
end
