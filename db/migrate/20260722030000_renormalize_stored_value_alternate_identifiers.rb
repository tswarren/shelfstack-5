# frozen_string_literal: true

# Re-applies full alternate-identifier normalization for installs that already
# ran the earlier lower()-only version of 20260722010000.
class RenormalizeStoredValueAlternateIdentifiers < ActiveRecord::Migration[8.1]
  NORMALIZE_SQL = <<~SQL.squish.freeze
    nullif(
      lower(
        regexp_replace(
          btrim(alternate_identifier),
          '[[:space:]-]',
          '',
          'g'
        )
      ),
      ''
    )
  SQL

  def up
    conflicts = select_all(<<~SQL.squish).to_a
      SELECT organization_id,
             #{NORMALIZE_SQL} AS normalized,
             string_agg(id::text, ',' ORDER BY id) AS account_ids
      FROM stored_value_accounts
      WHERE alternate_identifier IS NOT NULL
        AND #{NORMALIZE_SQL} IS NOT NULL
      GROUP BY organization_id, #{NORMALIZE_SQL}
      HAVING COUNT(*) > 1
    SQL
    if conflicts.any?
      details = conflicts.map { |row|
        "org=#{row['organization_id']} normalized=#{row['normalized']} account_ids=#{row['account_ids']}"
      }.join("; ")
      raise ActiveRecord::IrreversibleMigration,
            "Cannot renormalize stored_value_accounts.alternate_identifier: " \
            "duplicates exist after normalization (#{details})."
    end

    execute <<~SQL.squish
      UPDATE stored_value_accounts
      SET alternate_identifier = #{NORMALIZE_SQL}
      WHERE alternate_identifier IS NOT NULL
        AND alternate_identifier IS DISTINCT FROM #{NORMALIZE_SQL}
    SQL
  end

  def down
    # Irreversible.
  end
end
