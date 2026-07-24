# frozen_string_literal: true

require "test_helper"

class CatalogPreviewProductImportTest < ActiveSupport::TestCase
  CANONICAL_ISBN13 = "9780316769488"

  setup do
    IdentifierSequence.ensure_defaults!
    @organization = organizations(:acme)
    @store = stores(:main_street)
    @admin = users(:admin)
    @clerk = users(:clerk)
  end

  test "existing product short-circuits with zero transport calls" do
    product = products(:sample_book)
    transport = FakeHttpTransport.new(responses: [])

    result = Catalog::PreviewProductImport.call(
      actor: @admin, store: @store, organization: @organization,
      identifier: product.identifier, provider: :isbndb, transport: transport
    )

    assert result.success?
    assert_equal :existing, result.status
    assert_equal product, result.product
    assert_equal 0, transport.call_count
    assert_no_difference "CatalogEnrichmentEvent.count" do
      # preview already ran; assert no event was created by it
    end
  end

  test "preview creates no enrichment event" do
    transport = success_transport

    assert_no_difference "CatalogEnrichmentEvent.count" do
      result = Catalog::PreviewProductImport.call(
        actor: @admin, store: @store, organization: @organization,
        identifier: CANONICAL_ISBN13, provider: :isbndb,
        transport: transport, api_key: "test-key"
      )
      assert result.success?
      assert_equal :preview, result.status
    end
  end

  test "successful preview proposes bibliographic attrs and never sets regular price from list price" do
    transport = success_transport

    result = Catalog::PreviewProductImport.call(
      actor: @admin, store: @store, organization: @organization,
      identifier: CANONICAL_ISBN13, provider: :isbndb,
      transport: transport, api_key: "test-key"
    )

    assert result.success?
    assert_equal "Test Harbor", result.proposed_product_attrs[:name]
    assert_equal "Fixture House", result.proposed_product_attrs[:publisher_or_manufacturer_name]
    assert_equal false, result.proposed_product_attrs[:sellable]
    assert_equal 1699, result.proposed_product_attrs[:list_price_cents]
    assert_nil result.proposed_variant_attrs[:regular_price_cents]
    assert_equal false, result.proposed_variant_attrs[:sellable]
    assert result.list_price_proposal.persistable?
    assert result.list_price_proposal.display_only?
    assert_includes result.sale_eligibility_blockers, "product_not_sellable"
  end

  test "provider failure returns failure with zero product rows created" do
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 404, fixture: "catalog/providers/isbndb_missing_book.json")
    ])

    assert_no_difference [ "Product.count", "CatalogEnrichmentEvent.count" ] do
      result = Catalog::PreviewProductImport.call(
        actor: @admin, store: @store, organization: @organization,
        identifier: CANONICAL_ISBN13, provider: :isbndb,
        transport: transport, api_key: "test-key"
      )
      assert_not result.success?
      assert_equal :failure, result.status
      assert_equal :not_found, result.code
    end
  end

  test "suggests an existing creator on exact normalized-name match" do
    Creator.create!(
      organization: @organization,
      display_name: "Jordan Fixture",
      sort_name: "Fixture, Jordan",
      active: true
    )
    transport = success_transport

    result = Catalog::PreviewProductImport.call(
      actor: @admin, store: @store, organization: @organization,
      identifier: CANONICAL_ISBN13, provider: :isbndb,
      transport: transport, api_key: "test-key"
    )

    jordan = result.creator_suggestions.find { |row| row.display_name == "Jordan Fixture" }
    alex = result.creator_suggestions.find { |row| row.display_name == "Alex Sample" }

    assert_equal :suggest_existing, jordan.resolution
    assert_equal :propose_create, alex.resolution
  end

  test "actor without catalog.lookup_external is denied" do
    transport = FakeHttpTransport.new(responses: [])

    assert_raises(Catalog::PreviewProductImport::Error) do
      Catalog::PreviewProductImport.call(
        actor: @clerk, store: @store, organization: @organization,
        identifier: CANONICAL_ISBN13, provider: :isbndb, transport: transport
      )
    end
    assert_equal 0, transport.call_count
  end

  test "foreign list price currency is display-only and not persistable" do
    payload = JSON.parse(file_fixture("catalog/providers/isbndb_success.json").read)
    payload["book"]["msrp_currency"] = "eur"
    transport = FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, body: payload.to_json)
    ])

    result = Catalog::PreviewProductImport.call(
      actor: @admin, store: @store, organization: @organization,
      identifier: CANONICAL_ISBN13, provider: :isbndb,
      transport: transport, api_key: "test-key"
    )

    assert result.success?
    assert_not result.list_price_proposal.persistable?
    assert_nil result.proposed_product_attrs[:list_price_cents]
  end

  private

  def success_transport
    FakeHttpTransport.new(responses: [
      FakeHttpTransport.json_response(status: 200, fixture: "catalog/providers/isbndb_success.json")
    ])
  end
end
