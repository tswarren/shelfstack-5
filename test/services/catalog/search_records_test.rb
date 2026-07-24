# frozen_string_literal: true

require "test_helper"

class CatalogSearchRecordsTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
  end

  test "searches merchandise classes by name within organization" do
    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "merchandise_class",
      query: "fiction"
    )

    assert results.any?
    assert results.any? { |r| r.id == merchandise_classes(:fiction_primary).id }
    assert results.all? { |r| r.label.present? }
  end

  test "excludes inactive vendors by default" do
    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "vendor",
      query: "Old"
    )

    assert_empty results.map(&:id)
  end

  test "includes inactive vendors when requested" do
    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "vendor",
      query: "Old",
      include_inactive: true
    )

    assert_includes results.map(&:id), vendors(:inactive_vendor).id
  end

  test "scopes product variants by product_id" do
    product = products(:sample_book)

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: "",
      product_id: product.id
    )

    assert results.any?
    variant_ids = ProductVariant.where(id: results.map(&:id)).pluck(:product_id).uniq
    assert_equal [ product.id ], variant_ids
  end

  test "rejects unknown record type" do
    assert_raises(ArgumentError) do
      Catalog::SearchRecords.call(organization: @organization, record_type: "creator", query: "x")
    end
  end

  test "authorized? checks permission codes" do
    admin = users(:admin)
    store = stores(:main_street)

    assert Catalog::SearchRecords.authorized?(user: admin, store: store, record_type: "product")
  end

  test "excludes active variant when parent product is inactive" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)
    product.update!(status: "inactive")

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: variant.sku
    )

    assert_not_includes results.map(&:id), variant.id
  end

  test "includes inactive-product variant with status suffix when requested" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)
    product.update!(status: "inactive")

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: variant.sku,
      include_inactive: true
    )

    match = results.find { |r| r.id == variant.id }
    assert match
    assert match.inactive
    assert_match(/Inactive/, match.label)
  end

  test "finds variants by product identifier" do
    product = products(:sample_book)
    variant = product_variants(:sample_book_standard)

    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "product_variant",
      query: product.identifier
    )

    assert_includes results.map(&:id), variant.id
  end

  test "inactive vendor results include inactive flag when requested" do
    results = Catalog::SearchRecords.call(
      organization: @organization,
      record_type: "vendor",
      query: "Old",
      include_inactive: true
    )

    match = results.find { |r| r.id == vendors(:inactive_vendor).id }
    assert match
    assert match.inactive
    assert_match(/Inactive/, match.label)
  end
end
