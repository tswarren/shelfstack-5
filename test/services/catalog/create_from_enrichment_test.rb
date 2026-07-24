# frozen_string_literal: true

require "test_helper"

class CatalogCreateFromEnrichmentTest < ActiveSupport::TestCase
  CANONICAL_ISBN13 = "9780316769488"

  setup do
    IdentifierSequence.ensure_defaults!
    @organization = organizations(:acme)
    @store = stores(:main_street)
    @admin = users(:admin)
    @clerk = users(:clerk)
    @format = product_formats(:paperback)
    @retrieved_at = Time.zone.parse("2026-07-24 12:00:00")
  end

  test "successful create persists product variant creators and one enrichment event" do
    assert_difference [ "Product.count", "ProductVariant.count", "CatalogEnrichmentEvent.count" ], 1 do
      assert_difference "Creator.count", 2 do
        result = create_from_enrichment!
        assert result.success?
        assert_equal :created, result.status
        assert_equal "Test Harbor", result.product.name
        assert_equal CANONICAL_ISBN13, result.product.identifier
        assert_equal 1699, result.product.list_price_cents
        assert_nil result.variant.regular_price_cents
        assert_equal false, result.product.sellable?
        assert_equal false, result.variant.sellable?
        assert_equal "create", result.enrichment_event.action
        assert_equal "isbndb", result.enrichment_event.provider
        assert_equal 2, result.product.product_creators.count
      end
    end
  end

  test "list price is never copied to variant regular price even when supplied equal" do
    result = create_from_enrichment!(
      variant_attrs: {
        inventory_tracking_mode: "quantity",
        sellable: false,
        regular_price_cents: 1699
      }
    )

    assert result.success?
    assert_equal 1699, result.product.list_price_cents
    assert_nil result.variant.regular_price_cents
  end

  test "existing product short-circuits without creating rows" do
    existing = products(:sample_book)

    assert_no_difference [ "Product.count", "CatalogEnrichmentEvent.count", "Creator.count" ] do
      result = Catalog::CreateFromEnrichment.call(
        organization: @organization, actor: @admin, store: @store,
        identifier: existing.identifier,
        provider: "isbndb",
        provider_record_id: "x",
        retrieved_at: @retrieved_at,
        product_attrs: { name: "Should Not Create", product_type: "book", product_format_id: @format.id },
        variant_attrs: { inventory_tracking_mode: "quantity", sellable: false },
        creator_resolutions: []
      )

      assert_not result.success?
      assert_equal :existing, result.status
      assert_equal existing, result.product
    end
  end

  test "partial failure rolls back product variant creators and event" do
    assert_no_difference [ "Product.count", "ProductVariant.count", "Creator.count", "CatalogEnrichmentEvent.count" ] do
      result = Catalog::CreateFromEnrichment.call(
        organization: @organization, actor: @admin, store: @store,
        identifier: CANONICAL_ISBN13,
        provider: "isbndb",
        provider_record_id: CANONICAL_ISBN13,
        retrieved_at: @retrieved_at,
        product_attrs: {
          name: "Broken",
          product_type: "book",
          product_format_id: nil
        },
        variant_attrs: { inventory_tracking_mode: "quantity", sellable: false },
        creator_resolutions: [
          { action: "create", display_name: "Should Roll Back", role: "author" }
        ]
      )

      assert_not result.success?
    end
  end

  test "concurrent duplicate create is rejected or redirected to existing" do
    first = create_from_enrichment!
    assert first.success?

    assert_no_difference [ "Product.count", "CatalogEnrichmentEvent.count" ] do
      second = create_from_enrichment!
      assert_not second.success?
      assert_equal :existing, second.status
      assert_equal first.product.id, second.product.id
    end
  end

  test "actor without create_from_enrichment is denied" do
    assert_raises(Catalog::CreateFromEnrichment::Error) do
      Catalog::CreateFromEnrichment.call(
        organization: @organization, actor: @clerk, store: @store,
        identifier: CANONICAL_ISBN13,
        provider: "isbndb",
        provider_record_id: CANONICAL_ISBN13,
        retrieved_at: @retrieved_at,
        product_attrs: { name: "Nope", product_type: "book", product_format_id: @format.id },
        variant_attrs: { inventory_tracking_mode: "quantity", sellable: false }
      )
    end
  end

  test "mismatched list price currency is not persisted" do
    result = create_from_enrichment!(
      product_attrs: base_product_attrs.merge(
        list_price_cents: 1699,
        list_price_currency_code: "EUR"
      )
    )

    assert result.success?
    assert_nil result.product.list_price_cents
  end

  test "uses an existing creator resolution without creating a duplicate creator" do
    creator = Creator.create!(
      organization: @organization,
      display_name: "Jordan Fixture",
      sort_name: "Fixture, Jordan",
      active: true
    )

    assert_difference "Creator.count", 1 do
      result = Catalog::CreateFromEnrichment.call(
        organization: @organization, actor: @admin, store: @store,
        identifier: CANONICAL_ISBN13,
        provider: "isbndb",
        provider_record_id: CANONICAL_ISBN13,
        retrieved_at: @retrieved_at,
        product_attrs: base_product_attrs,
        variant_attrs: base_variant_attrs,
        creator_resolutions: [
          { action: "use_existing", creator_id: creator.id, role: "author" },
          { action: "create", display_name: "Alex Sample", role: "author" }
        ]
      )
      assert result.success?
      assert_includes result.product.creators.pluck(:id), creator.id
    end
  end

  private

  def base_product_attrs
    {
      name: "Test Harbor",
      subtitle: nil,
      description: "A deterministic fixture book used only for adapter tests.",
      product_type: "book",
      product_format_id: @format.id,
      publisher_or_manufacturer_name: "Fixture House",
      language_code: "en",
      edition_statement: "1st",
      publication_date: Date.new(2014, 2, 11),
      publication_date_precision: "day",
      status: "active",
      sellable: false,
      list_price_cents: 1699,
      list_price_currency_code: "USD"
    }
  end

  def base_variant_attrs
    {
      name: "Standard",
      inventory_tracking_mode: "quantity",
      regular_price_cents: nil,
      status: "active",
      sellable: false,
      purchasable: true
    }
  end

  def create_from_enrichment!(product_attrs: base_product_attrs, variant_attrs: base_variant_attrs, creator_resolutions: nil)
    Catalog::CreateFromEnrichment.call(
      organization: @organization,
      actor: @admin,
      store: @store,
      identifier: CANONICAL_ISBN13,
      provider: "isbndb",
      provider_record_id: CANONICAL_ISBN13,
      retrieved_at: @retrieved_at,
      product_attrs: product_attrs,
      variant_attrs: variant_attrs,
      creator_resolutions: creator_resolutions || [
        { action: "create", display_name: "Jordan Fixture", role: "author" },
        { action: "create", display_name: "Alex Sample", role: "author" }
      ],
      accepted_warnings: [ { "code" => "example", "message" => "accepted" } ]
    )
  end
end
