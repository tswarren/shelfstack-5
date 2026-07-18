# frozen_string_literal: true

class CreateIdentifierSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :identifier_sequences, id: false, primary_key: :namespace do |t|
      t.string :namespace, null: false, limit: 2
      t.bigint :next_value, null: false, default: 1
      t.timestamps
    end

    add_check_constraint :identifier_sequences,
                         "namespace IN ('21', '27', '28', '29')",
                         name: "identifier_sequences_namespace_check"
    add_check_constraint :identifier_sequences,
                         "next_value >= 1",
                         name: "identifier_sequences_next_value_positive"
  end
end
