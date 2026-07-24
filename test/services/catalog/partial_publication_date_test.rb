# frozen_string_literal: true

require "test_helper"

class CatalogPartialPublicationDateTest < ActiveSupport::TestCase
  test "validate accepts a blank date and precision" do
    result = Catalog::PartialPublicationDate.validate(date: nil, precision: nil)

    assert result.valid?
    assert_nil result.date
  end

  test "validate rejects date present without precision" do
    result = Catalog::PartialPublicationDate.validate(date: Date.new(2020, 1, 1), precision: nil)

    assert_not result.valid?
    assert_includes result.errors.join, "both be present or both be blank"
  end

  test "validate rejects precision present without date" do
    result = Catalog::PartialPublicationDate.validate(date: nil, precision: "year")

    assert_not result.valid?
  end

  test "validate rejects an unrecognized precision value" do
    result = Catalog::PartialPublicationDate.validate(date: Date.new(2020, 1, 1), precision: "decade")

    assert_not result.valid?
    assert_includes result.errors.join, "must be one of"
  end

  test "validate requires January 1 for year precision" do
    result = Catalog::PartialPublicationDate.validate(date: Date.new(2020, 3, 1), precision: "year")

    assert_not result.valid?
    assert_includes result.errors.join, "January 1"
  end

  test "validate accepts January 1 for year precision" do
    result = Catalog::PartialPublicationDate.validate(date: Date.new(2020, 1, 1), precision: "year")

    assert result.valid?
  end

  test "validate requires day 1 for month precision" do
    result = Catalog::PartialPublicationDate.validate(date: Date.new(2020, 3, 15), precision: "month")

    assert_not result.valid?
    assert_includes result.errors.join, "day 1"
  end

  test "validate accepts any day for day precision" do
    result = Catalog::PartialPublicationDate.validate(date: Date.new(2020, 3, 15), precision: "day")

    assert result.valid?
  end

  test "parse_parts builds January 1 from a bare year" do
    result = Catalog::PartialPublicationDate.parse_parts(precision: "year", year: "2020", month: nil, day: nil)

    assert result.valid?
    assert_equal Date.new(2020, 1, 1), result.date
  end

  test "parse_parts builds day 1 from year and month" do
    result = Catalog::PartialPublicationDate.parse_parts(precision: "month", year: "2020", month: "5", day: nil)

    assert result.valid?
    assert_equal Date.new(2020, 5, 1), result.date
  end

  test "parse_parts builds the exact date for day precision" do
    result = Catalog::PartialPublicationDate.parse_parts(precision: "day", year: "2020", month: "5", day: "15")

    assert result.valid?
    assert_equal Date.new(2020, 5, 15), result.date
  end

  test "parse_parts returns no-op result when all parts are blank" do
    result = Catalog::PartialPublicationDate.parse_parts(precision: "", year: "", month: "", day: "")

    assert result.valid?
    assert_nil result.date
    assert_nil result.precision
  end

  test "parse_parts requires year" do
    result = Catalog::PartialPublicationDate.parse_parts(precision: "year", year: "", month: nil, day: nil)

    assert_not result.valid?
    assert_includes result.errors.join, "year is required"
  end

  test "parse_parts rejects an impossible calendar date" do
    result = Catalog::PartialPublicationDate.parse_parts(precision: "day", year: "2020", month: "2", day: "31")

    assert_not result.valid?
    assert_includes result.errors.join, "not a valid date"
  end
end
