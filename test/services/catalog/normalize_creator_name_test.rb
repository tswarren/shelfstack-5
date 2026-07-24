# frozen_string_literal: true

require "test_helper"

class CatalogNormalizeCreatorNameTest < ActiveSupport::TestCase
  test "collapses internal whitespace and strips leading/trailing whitespace" do
    assert_equal "jane smith", Catalog::NormalizeCreatorName.call("  Jane   Smith  ")
  end

  test "downcases the name" do
    assert_equal "ursula k. le guin", Catalog::NormalizeCreatorName.call("URSULA K. LE GUIN")
  end

  test "retains punctuation and diacritics" do
    assert_equal "gabriel garcía márquez", Catalog::NormalizeCreatorName.call("Gabriel García Márquez")
  end

  test "returns an empty string for blank input" do
    assert_equal "", Catalog::NormalizeCreatorName.call(nil)
    assert_equal "", Catalog::NormalizeCreatorName.call("")
  end
end
