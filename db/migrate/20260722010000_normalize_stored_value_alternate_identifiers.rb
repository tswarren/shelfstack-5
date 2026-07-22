# frozen_string_literal: true

class NormalizeStoredValueAlternateIdentifiers < ActiveRecord::Migration[8.1]
  # Must match StoredValueAccount.normalize_alternate_identifier:
  # btrim + remove POSIX whitespace and hyphens + lower + nullif blank.
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
    conflicts = select_conflict_rows
    if conflicts.any?
      details = conflicts.map { |row|
        "org=#{row['organization_id']} normalized=#{row['normalized']} account_ids=#{row['account_ids']}"
      }.join("; ")
      raise ActiveRecord::IrreversibleMigration,
            "Cannot normalize stored_value_accounts.alternate_identifier: " \
            "duplicates exist after normalization (#{details}). " \
            "Remediate those accounts before deploying this migration."
    end

    canonical_collisions = select_canonical_collisions
    if canonical_collisions.any?
      details = canonical_collisions.map { |row|
        "org=#{row['organization_id']} value=#{row['value']} " \
          "alternate_account_id=#{row['alternate_account_id']} " \
          "canonical_account_id=#{row['canonical_account_id']}"
      }.join("; ")
      raise ActiveRecord::IrreversibleMigration,
            "Cannot normalize stored_value_accounts.alternate_identifier: " \
            "normalized alternates collide with account numbers (#{details}). " \
            "Remediate those accounts before deploying this migration."
    end

    say_with_time "normalize stored_value_accounts.alternate_identifier" do
      execute <<~SQL.squish
        UPDATE stored_value_accounts
        SET alternate_identifier = #{NORMALIZE_SQL}
        WHERE alternate_identifier IS NOT NULL
          AND alternate_identifier IS DISTINCT FROM #{NORMALIZE_SQL}
      SQL
    end
  end

  def down
    # Irreversible: original case and separators are not retained.
  end

  private

  def select_conflict_rows
    select_all(<<~SQL.squish).to_a
      SELECT organization_id,
             #{NORMALIZE_SQL} AS normalized,
             string_agg(id::text, ',' ORDER BY id) AS account_ids
      FROM stored_value_accounts
      WHERE alternate_identifier IS NOT NULL
        AND #{NORMALIZE_SQL} IS NOT NULL
      GROUP BY organization_id, #{NORMALIZE_SQL}
      HAVING COUNT(*) > 1
    SQL
  end

  def select_canonical_collisions
    select_all(<<~SQL.squish).to_a
      SELECT a.organization_id,
             #{NORMALIZE_SQL.gsub('alternate_identifier', 'a.alternate_identifier')} AS value,
             a.id AS alternate_account_id,
             b.id AS canonical_account_id
      FROM stored_value_accounts a
      INNER JOIN stored_value_accounts b
        ON b.organization_id = a.organization_id
       AND b.account_number = #{NORMALIZE_SQL.gsub('alternate_identifier', 'a.alternate_identifier')}
       AND b.id <> a.id
      WHERE a.alternate_identifier IS NOT NULL
        AND #{NORMALIZE_SQL.gsub('alternate_identifier', 'a.alternate_identifier')} IS NOT NULL
    SQL
  end
end
