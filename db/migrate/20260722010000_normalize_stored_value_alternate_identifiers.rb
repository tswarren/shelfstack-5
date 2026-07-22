# frozen_string_literal: true

class NormalizeStoredValueAlternateIdentifiers < ActiveRecord::Migration[8.1]
  def up
    conflicts = select_conflict_rows
    if conflicts.any?
      details = conflicts.map { |row|
        "normalized=#{row['normalized']} account_ids=#{row['account_ids']}"
      }.join("; ")
      raise ActiveRecord::IrreversibleMigration,
            "Cannot normalize stored_value_accounts.alternate_identifier: " \
            "case-insensitive duplicates exist (#{details}). " \
            "Remediate those accounts before deploying this migration."
    end

    canonical_collisions = select_canonical_collisions
    if canonical_collisions.any?
      details = canonical_collisions.map { |row|
        "value=#{row['value']} alternate_account_id=#{row['alternate_account_id']} " \
          "canonical_account_id=#{row['canonical_account_id']}"
      }.join("; ")
      raise ActiveRecord::IrreversibleMigration,
            "Cannot normalize stored_value_accounts.alternate_identifier: " \
            "normalized alternates collide with account numbers (#{details}). " \
            "Remediate those accounts before deploying this migration."
    end

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

  private

  def select_conflict_rows
    select_all(<<~SQL.squish).to_a
      SELECT lower(alternate_identifier) AS normalized,
             string_agg(id::text, ',' ORDER BY id) AS account_ids
      FROM stored_value_accounts
      WHERE alternate_identifier IS NOT NULL
      GROUP BY lower(alternate_identifier)
      HAVING COUNT(*) > 1
    SQL
  end

  def select_canonical_collisions
    select_all(<<~SQL.squish).to_a
      SELECT a.alternate_identifier AS value,
             a.id AS alternate_account_id,
             b.id AS canonical_account_id
      FROM stored_value_accounts a
      INNER JOIN stored_value_accounts b
        ON b.organization_id = a.organization_id
       AND b.account_number = lower(a.alternate_identifier)
       AND b.id <> a.id
      WHERE a.alternate_identifier IS NOT NULL
    SQL
  end
end
