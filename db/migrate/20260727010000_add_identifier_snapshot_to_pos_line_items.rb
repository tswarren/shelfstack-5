# frozen_string_literal: true

class AddIdentifierSnapshotToPosLineItems < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_line_items, :identifier_snapshot, :string
  end
end
