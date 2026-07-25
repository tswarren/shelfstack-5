# frozen_string_literal: true

require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @product = products(:sample_book)
  end

  test "normalizes language_code alpha-2 and BCP-47 to ISO 639-2" do
    @product.language_code = "  EN-US  "
    @product.valid?

    assert_equal "eng", @product.language_code
  end

  test "leaves a blank language_code untouched" do
    @product.language_code = nil
    @product.valid?

    assert_nil @product.language_code
  end

  test "unknown language_code values normalize to blank" do
    @product.language_code = "zzz"
    @product.valid?

    assert_nil @product.language_code
    assert @product.valid?
  end

  test "allows a blank publication_date" do
    @product.publication_date = nil

    assert @product.valid?
  end

  test "allows an exact publication_date" do
    @product.publication_date = Date.new(2020, 6, 15)

    assert @product.valid?
  end
end
