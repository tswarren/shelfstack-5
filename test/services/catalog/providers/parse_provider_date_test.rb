# frozen_string_literal: true

require "test_helper"

module Catalog
  module Providers
    class ParseProviderDateTest < ActiveSupport::TestCase
      test "parses full calendar days" do
        assert_equal Date.new(2014, 2, 11), ParseProviderDate.call("2014-02-11")
        assert_equal Date.new(2014, 2, 11), ParseProviderDate.call("2014-02-11T00:00:00Z")
        assert_equal Date.new(2014, 2, 11), ParseProviderDate.call("2014-02-11 extra")
      end

      test "ignores year-only and month-only strings" do
        assert_nil ParseProviderDate.call("2014")
        assert_nil ParseProviderDate.call("2014-02")
      end

      test "ignores blank and unrecognized text" do
        assert_nil ParseProviderDate.call(nil)
        assert_nil ParseProviderDate.call("")
        assert_nil ParseProviderDate.call("February 2014")
        assert_nil ParseProviderDate.call("2014-02-31")
        assert_nil ParseProviderDate.call("20140211")
      end
    end
  end
end
