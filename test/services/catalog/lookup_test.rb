# frozen_string_literal: true

require "test_helper"

class CatalogLookupTest < ActiveSupport::TestCase
  test "finds product by alternate using UPC/EAN equivalent values" do
    product = products(:sample_book)
    product.update!(alternate_identifier: "0036000291452")

    result = Catalog::Lookup.call(organization: organizations(:acme), query: "036000291452")

    assert_includes result.products, product
    assert_equal :alternate, result.match_kind
  end

  test "finds product when alternate stored as UPC and query is EAN" do
    product = products(:sample_book)
    product.update_columns(alternate_identifier: "036000291452")

    result = Catalog::Lookup.call(organization: organizations(:acme), query: "0036000291452")

    assert_includes result.products, product
    assert_equal :alternate, result.match_kind
  end
end
