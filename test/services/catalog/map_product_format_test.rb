# frozen_string_literal: true

require "test_helper"

class CatalogMapProductFormatTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:acme)
  end

  test "exact code match suggests the format" do
    result = Catalog::MapProductFormat.call(organization: @organization, provider_format: "hardcover")

    assert_equal product_formats(:hardcover), result.product_format
    assert_nil result.warning
  end

  test "exact name match is case-insensitive" do
    result = Catalog::MapProductFormat.call(organization: @organization, provider_format: "Hardcover")

    assert_equal product_formats(:hardcover), result.product_format
    assert_nil result.warning
  end

  test "conservative token map resolves a recognized alias to a unique active format" do
    result = Catalog::MapProductFormat.call(organization: @organization, provider_format: "Hardback")

    assert_equal product_formats(:hardcover), result.product_format
    assert_nil result.warning
  end

  test "a token that is recognized but has no matching active format in this org returns no suggestion" do
    result = Catalog::MapProductFormat.call(organization: @organization, provider_format: "Audiobook")

    assert_nil result.product_format
    assert_nil result.warning
  end

  test "an unrecognized provider format returns no suggestion and no warning" do
    result = Catalog::MapProductFormat.call(organization: @organization, provider_format: "Something Unusual")

    assert_nil result.product_format
    assert_nil result.warning
  end

  test "blank provider format returns no suggestion" do
    result = Catalog::MapProductFormat.call(organization: @organization, provider_format: nil)

    assert_nil result.product_format
    assert_nil result.warning
  end

  test "multiple active matches return no suggestion plus a warning" do
    result = Catalog::MapProductFormat.call(organization: @organization, provider_format: "Trade Paperback")

    assert_nil result.product_format
    assert_not_nil result.warning
    assert_equal "ambiguous_product_format", result.warning.code
    assert_includes result.warning.details[:candidate_product_format_ids], product_formats(:trade_paperback_a).id
    assert_includes result.warning.details[:candidate_product_format_ids], product_formats(:trade_paperback_b).id
  end

  test "only active formats are considered, so an inactive duplicate name does not create ambiguity" do
    result = Catalog::MapProductFormat.call(organization: @organization, provider_format: "Hardcover")

    assert_equal product_formats(:hardcover), result.product_format
    assert_nil result.warning
  end

  test "never creates, updates, or writes a ProductFormat row" do
    assert_no_difference -> { ProductFormat.count } do
      Catalog::MapProductFormat.call(organization: @organization, provider_format: "Hardcover")
      Catalog::MapProductFormat.call(organization: @organization, provider_format: "Trade Paperback")
      Catalog::MapProductFormat.call(organization: @organization, provider_format: "Unrecognized Format")
    end
  end
end
