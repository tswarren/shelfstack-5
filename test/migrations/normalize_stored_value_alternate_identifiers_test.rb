# frozen_string_literal: true

require "test_helper"

class NormalizeStoredValueAlternateIdentifiersTest < ActiveSupport::TestCase
  # Must match db/migrate/20260722010000_normalize_stored_value_alternate_identifiers.rb
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

  setup do
    @org = organizations(:acme)
    @admin = users(:admin)
    IdentifierSequence.ensure_defaults!
  end

  test "normalization matches ruby and detects hyphen space case equivalents within org" do
    a = create_account
    b = create_account
    set_alternate!(a, "PREPRINT-123")
    set_alternate!(b, "preprint 123")

    rows = ActiveRecord::Base.connection.select_all(<<~SQL.squish).to_a
      SELECT organization_id,
             #{NORMALIZE_SQL} AS normalized,
             COUNT(*) AS cnt
      FROM stored_value_accounts
      WHERE id IN (#{a.id}, #{b.id})
      GROUP BY organization_id, #{NORMALIZE_SQL}
      HAVING COUNT(*) > 1
    SQL
    assert_equal 1, rows.size
    assert_equal "preprint123", rows.first["normalized"]
    assert_equal StoredValueAccount.normalize_alternate_identifier("PREPRINT-123"), rows.first["normalized"]
  end

  test "duplicate detection SQL is organization scoped" do
    source = File.read(
      Rails.root.join("db/migrate/20260722010000_normalize_stored_value_alternate_identifiers.rb")
    )
    assert_match(/GROUP BY organization_id/, source)
    assert_match(/\[\[:space:\]-\]/, source)
  end

  private

  def create_account
    StoredValue::CreateAccount.call(
      organization: @org,
      account_type: "gift_card",
      actor: @admin
    ).account
  end

  def set_alternate!(account, value)
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      UPDATE stored_value_accounts
      SET alternate_identifier = #{ActiveRecord::Base.connection.quote(value)}
      WHERE id = #{account.id}
    SQL
  end
end
