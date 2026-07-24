# frozen_string_literal: true

require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @product = products(:sample_book)
  end

  test "normalizes language_code whitespace and case" do
    @product.language_code = "  EN-US  "
    @product.valid?

    assert_equal "en-us", @product.language_code
  end

  test "leaves a blank language_code untouched" do
    @product.language_code = nil
    @product.valid?

    assert_nil @product.language_code
  end

  test "allows a blank publication_date and precision together" do
    @product.publication_date = nil
    @product.publication_date_precision = nil

    assert @product.valid?
  end

  test "rejects publication_date without precision" do
    @product.publication_date = Date.new(2020, 1, 1)
    @product.publication_date_precision = nil

    assert_not @product.valid?
    assert_includes @product.errors[:publication_date].join, "both be present or both be blank"
  end

  test "rejects precision without publication_date" do
    @product.publication_date = nil
    @product.publication_date_precision = "year"

    assert_not @product.valid?
  end

  test "year precision requires January 1" do
    @product.publication_date = Date.new(2020, 6, 15)
    @product.publication_date_precision = "year"

    assert_not @product.valid?
    assert_includes @product.errors[:publication_date].join, "January 1"
  end

  test "year precision accepts January 1" do
    @product.publication_date = Date.new(2020, 1, 1)
    @product.publication_date_precision = "year"

    assert @product.valid?
  end

  test "month precision requires day 1" do
    @product.publication_date = Date.new(2020, 6, 15)
    @product.publication_date_precision = "month"

    assert_not @product.valid?
    assert_includes @product.errors[:publication_date].join, "day 1"
  end

  test "month precision accepts day 1" do
    @product.publication_date = Date.new(2020, 6, 1)
    @product.publication_date_precision = "month"

    assert @product.valid?
  end

  test "day precision accepts any day" do
    @product.publication_date = Date.new(2020, 6, 15)
    @product.publication_date_precision = "day"

    assert @product.valid?
  end

  test "database check constraint enforces publication_date and precision both-or-neither" do
    @product.update!(publication_date: nil, publication_date_precision: nil)

    assert_raises(ActiveRecord::StatementInvalid) do
      @product.update_column(:publication_date, Date.new(2020, 1, 1))
    end
  end
end
