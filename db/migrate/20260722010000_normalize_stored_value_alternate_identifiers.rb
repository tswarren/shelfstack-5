# frozen_string_literal: true

class NormalizeStoredValueAlternateIdentifiers < ActiveRecord::Migration[8.1]
  def up
    say_with_time "downcase stored_value_accounts.alternate_identifier" do
      execute <<~SQL.squish
        UPDATE stored_value_accounts
        SET alternate_identifier = lower(alternate_identifier)
        WHERE alternate_identifier IS NOT NULL
          AND alternate_identifier <> lower(alternate_identifier)
      SQL
    end
  end

  def down
    # Irreversible: original case is not retained.
  end
end
