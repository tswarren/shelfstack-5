# frozen_string_literal: true

module Catalog
  # Creator name normalization v1 (phase-08 §7): unicode-normalize, strip,
  # collapse internal whitespace, lowercase for matching. Punctuation and
  # diacritics are deliberately retained -- stripping them risks more false
  # matches than it prevents.
  module NormalizeCreatorName
    module_function

    def call(name)
      return "" if name.blank?

      name.to_s.unicode_normalize(:nfc).strip.gsub(/\s+/, " ").downcase
    end
  end
end
