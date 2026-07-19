# frozen_string_literal: true

class AddExternalVoidConfirmationToPosTenders < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_tenders, :external_void_confirmed_at, :datetime
    add_column :pos_tenders, :external_void_reference, :string
    add_reference :pos_tenders, :external_void_confirmed_by_user,
                  foreign_key: { to_table: :users, on_delete: :restrict },
                  null: true
  end
end
