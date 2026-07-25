# frozen_string_literal: true

require "test_helper"

module Catalog
  class LanguageCodesTest < ActiveSupport::TestCase
    test "normalize maps alpha-2 and BCP-47 to curated alpha-3" do
      assert_equal "eng", LanguageCodes.normalize("EN")
      assert_equal "eng", LanguageCodes.normalize("en-US")
      assert_equal "fra", LanguageCodes.normalize("fr")
      assert_equal "spa", LanguageCodes.normalize("es-MX")
    end

    test "normalize keeps curated alpha-3 codes" do
      assert_equal "eng", LanguageCodes.normalize("eng")
      assert_equal "deu", LanguageCodes.normalize("DEU")
    end

    test "normalize blanks unknown or empty values" do
      assert_nil LanguageCodes.normalize(nil)
      assert_nil LanguageCodes.normalize("")
      assert_nil LanguageCodes.normalize("zz")
      assert_nil LanguageCodes.normalize("not-a-language")
    end

    test "label_for returns English name with code" do
      assert_equal "English (eng)", LanguageCodes.label_for("eng")
      assert_nil LanguageCodes.label_for(nil)
    end

    test "OPTIONS include the default eng code" do
      assert_includes LanguageCodes::CODES, LanguageCodes::DEFAULT
      assert LanguageCodes::OPTIONS.any? { |label, code| code == "eng" && label.include?("English") }
    end
  end
end
