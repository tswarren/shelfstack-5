# frozen_string_literal: true

require "test_helper"

class IdentifiersNormalizeTest < ActiveSupport::TestCase
  test "blank input is not applicable" do
    result = Identifiers::Normalize.call("  ")

    assert_equal :blank, result.type
    assert_equal :not_applicable, result.validation_status
    assert_equal "", result.canonical
  end

  test "valid ISBN-10 normalizes to ISBN-13 canonical form" do
    result = Identifiers::Normalize.call("0-306-40615-2")

    assert_equal :isbn13, result.type
    assert_equal :valid, result.validation_status
    assert_equal "9780306406157", result.canonical
  end

  test "invalid ISBN-10-shaped input is invalid with warning" do
    result = Identifiers::Normalize.call("0-306-40615-3")

    assert_equal :isbn13, result.type
    assert_equal :invalid, result.validation_status
    assert_includes result.warnings, "invalid ISBN-10 check digit"
  end

  test "valid UPC-A canonicalizes to zero-padded EAN-13 form" do
    result = Identifiers::Normalize.call("012345678905")

    assert_equal :upc_a, result.type
    assert_equal :valid, result.validation_status
    assert_equal "0012345678905", result.canonical
  end

  test "leading-zero EAN equivalent of UPC is valid ean13" do
    result = Identifiers::Normalize.call("0012345678905")

    assert_equal :ean13, result.type
    assert_equal :valid, result.validation_status
    assert_equal "0012345678905", result.canonical
  end

  test "invalid 13-digit checksum warns" do
    result = Identifiers::Normalize.call("9780306406158")

    assert_equal :isbn13, result.type
    assert_equal :warning, result.validation_status
    assert_includes result.warnings, "invalid EAN-13 check digit"
  end

  test "generated namespace 28 is recognized" do
    result = Identifiers::Normalize.call("2800000000011")

    assert_equal :generated_28, result.type
    assert_equal :valid, result.validation_status
  end
end
