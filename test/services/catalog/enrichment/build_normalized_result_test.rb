# frozen_string_literal: true

require "test_helper"

class CatalogEnrichmentBuildNormalizedResultTest < ActiveSupport::TestCase
  test "builds a fully populated normalized result" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "0316769487",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      provider_record_id: "9780316769488",
      title: "Test Harbor",
      subtitle: "A Fixture Novel",
      description: "A deterministic fixture.",
      creators: [ { display_name: "Jordan Fixture", role: "author" } ],
      publisher: "Fixture House",
      publication_date: Date.new(2014, 2, 11),
      language_code: "en",
      edition_statement: "1st",
      provider_format: "Paperback",
      external_subjects: [ "Fiction" ],
      list_price: { amount: "16.99", currency_code: "usd" },
      images: [ { source_url: "https://images.example.test/cover.jpg" } ]
    )

    assert_instance_of Catalog::Enrichment::NormalizedResult, result
    assert_equal "Test Harbor", result.title
    assert_equal "isbndb", result.provider
    assert_equal 1, result.creators.size
    assert_equal "author", result.creators.first.role
    assert_equal 0, result.creators.first.position
    assert_equal Date.new(2014, 2, 11), result.publication_date
    assert_equal "eng", result.language_code
    assert_equal 1699, result.list_price.amount_cents
    assert_equal "USD", result.list_price.currency_code
    assert_equal [ "Fiction" ], result.external_subjects
  end

  test "deep freezes the result and every nested collection" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      creators: [ { display_name: "Jordan Fixture", role: "author" } ],
      external_subjects: [ "Fiction" ],
      images: [ { source_url: "https://images.example.test/cover.jpg" } ],
      warnings: [ { code: "sample_warning", message: "example", details: { key: "value" } } ]
    )

    assert result.frozen?
    assert result.creators.frozen?
    assert result.creators.first.frozen?
    assert result.external_subjects.frozen?
    assert result.external_subjects.first.frozen?
    assert result.images.frozen?
    assert result.images.first.frozen?
    assert result.warnings.frozen?
    assert result.warnings.first.frozen?
    assert result.warnings.first.details.frozen?

    assert_raises(FrozenError) { result.creators << :nope }
    assert_raises(FrozenError) { result.warnings.first.details[:key] = "changed" }
  end

  test "missing creator role normalizes to contributor with a warning" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      creators: [ { display_name: "No Role Given" } ]
    )

    assert_equal "contributor", result.creators.first.role
    assert_equal 1, result.warnings.size
    assert_equal "creator_role_unrecognized", result.warnings.first.code
  end

  test "unrecognized creator role normalizes to contributor with a warning" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      creators: [ { display_name: "Ghost Writer", role: "ghostwriter" } ]
    )

    assert_equal "contributor", result.creators.first.role
    assert_equal 1, result.warnings.size
    assert_equal "creator_role_unrecognized", result.warnings.first.code
  end

  test "provider order becomes contiguous zero-based creator positions" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      creators: [
        { display_name: "First Author", role: "author" },
        { display_name: "Second Author", role: "editor" },
        { display_name: "Third Author", role: "illustrator" }
      ]
    )

    assert_equal [ 0, 1, 2 ], result.creators.map(&:position)
    assert_equal %w[author editor illustrator], result.creators.map(&:role)
  end

  test "negative list price is rejected with a warning and no money value" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      list_price: { amount: "-5.00", currency_code: "USD" }
    )

    assert_nil result.list_price
    assert_equal 1, result.warnings.size
    assert_equal "invalid_list_price", result.warnings.first.code
  end

  test "non-numeric list price is rejected with a warning" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      list_price: { amount: "not-a-number", currency_code: "USD" }
    )

    assert_nil result.list_price
    assert_equal "invalid_list_price", result.warnings.first.code
  end

  test "list price rounds half up to integer cents using decimal arithmetic" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      list_price: { amount: "10.005", currency_code: "usd" }
    )

    assert_equal 1001, result.list_price.amount_cents
    assert_equal "USD", result.list_price.currency_code
    assert_kind_of Integer, result.list_price.amount_cents
  end

  test "absent list price currency stays null rather than being assumed" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      list_price: { amount: "9.00", currency_code: nil }
    )

    assert_equal 900, result.list_price.amount_cents
    assert_nil result.list_price.currency_code
  end

  test "absent list price produces no money value and no warning" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb"
    )

    assert_nil result.list_price
    assert_empty result.warnings
  end

  test "absent publication date stays nil" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      publication_date: nil
    )

    assert_nil result.publication_date
  end

  test "publication_date accepts Date and TimeWithZone calendar days" do
    date_result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      publication_date: Date.new(2014, 2, 11)
    )
    assert_equal Date.new(2014, 2, 11), date_result.publication_date

    zone_result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      publication_date: Time.zone.parse("2014-02-11 15:30:00")
    )
    assert_equal Date.new(2014, 2, 11), zone_result.publication_date
  end

  test "publication_date ISO day strings use ParseProviderDate" do
    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      publication_date: "2014-02-11T00:00:00Z"
    )

    assert_equal Date.new(2014, 2, 11), result.publication_date
  end

  test "publication_date year-only and month-only strings stay nil" do
    year_only = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      publication_date: "2014"
    )
    month_only = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      publication_date: "2014-02"
    )

    assert_nil year_only.publication_date
    assert_nil month_only.publication_date
  end

  test "publication_date rejects duck-typed to_date objects" do
    duck = Object.new
    def duck.to_date
      Date.new(2014, 1, 1)
    end

    result = Catalog::Enrichment::BuildNormalizedResult.call(
      requested_identifier: "9780316769488",
      canonical_identifier: "9780316769488",
      provider: "isbndb",
      publication_date: duck
    )

    assert_nil result.publication_date
  end
end
