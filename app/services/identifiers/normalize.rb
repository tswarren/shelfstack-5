# frozen_string_literal: true

module Identifiers
  class Normalize < ApplicationService
    GENERATED_PREFIXES = {
      "21" => :generated_21,
      "27" => :generated_27,
      "28" => :generated_28,
      "29" => :generated_29
    }.freeze

    ISBN10_PATTERN = /\A\d{9}[\dXx]\z/
    DIGITS_ONLY = /\A\d+\z/

    def initialize(raw)
      @raw = raw
    end

    def call
      original = @raw.to_s
      stripped = strip_separators(original)

      if stripped.blank?
        return NormalizedIdentifier.new(
          original: original,
          normalized: "",
          canonical: "",
          type: :blank,
          validation_status: :not_applicable,
          warnings: []
        )
      end

      if isbn10_candidate?(stripped)
        return normalize_isbn10(original, stripped)
      end

      if stripped.match?(DIGITS_ONLY) && stripped.length == 12
        return normalize_upc_a(original, stripped)
      end

      if stripped.match?(DIGITS_ONLY) && stripped.length == 13
        return normalize_thirteen_digit(original, stripped)
      end

      if other_trade_identifier?(stripped)
        return NormalizedIdentifier.new(
          original: original,
          normalized: stripped,
          canonical: stripped,
          type: :other,
          validation_status: :valid,
          warnings: []
        )
      end

      NormalizedIdentifier.new(
        original: original,
        normalized: stripped,
        canonical: stripped,
        type: :other,
        validation_status: :invalid,
        warnings: [ "unrecognized identifier format" ]
      )
    end

    private

    def strip_separators(value)
      value.strip.gsub(/[\s\-]/, "")
    end

    def isbn10_candidate?(stripped)
      stripped.match?(ISBN10_PATTERN)
    end

    def normalize_isbn10(original, stripped)
      body = stripped[0, 9]
      check = stripped[9].upcase

      unless valid_isbn10_check?(body, check)
        return NormalizedIdentifier.new(
          original: original,
          normalized: stripped,
          canonical: stripped,
          type: :isbn13,
          validation_status: :invalid,
          warnings: [ "invalid ISBN-10 check digit" ]
        )
      end

      twelve = "978#{body}"
      canonical = twelve + ean13_check_digit(twelve).to_s

      NormalizedIdentifier.new(
        original: original,
        normalized: stripped,
        canonical: canonical,
        type: :isbn13,
        validation_status: :valid,
        warnings: []
      )
    end

    def normalize_upc_a(original, stripped)
      canonical = "0#{stripped}"

      unless valid_upc_check?(stripped)
        return NormalizedIdentifier.new(
          original: original,
          normalized: stripped,
          canonical: canonical,
          type: :upc_a,
          validation_status: :warning,
          warnings: [ "invalid UPC-A check digit" ]
        )
      end

      NormalizedIdentifier.new(
        original: original,
        normalized: stripped,
        canonical: canonical,
        type: :upc_a,
        validation_status: :valid,
        warnings: []
      )
    end

    def other_trade_identifier?(stripped)
      stripped.match?(/\A[A-Za-z0-9][A-Za-z0-9._-]{2,31}\z/) && !stripped.match?(DIGITS_ONLY)
    end

    def normalize_thirteen_digit(original, stripped)
      prefix = stripped[0, 2]
      generated_type = GENERATED_PREFIXES[prefix]
      checksum_valid = valid_ean13_check?(stripped)

      if generated_type
        return build_thirteen_digit_result(
          original: original,
          normalized: stripped,
          canonical: stripped,
          type: generated_type,
          checksum_valid: checksum_valid
        )
      end

      if isbn13_range?(stripped)
        return build_thirteen_digit_result(
          original: original,
          normalized: stripped,
          canonical: stripped,
          type: :isbn13,
          checksum_valid: checksum_valid
        )
      end

      build_thirteen_digit_result(
        original: original,
        normalized: stripped,
        canonical: stripped,
        type: :ean13,
        checksum_valid: checksum_valid
      )
    end

    def build_thirteen_digit_result(original:, normalized:, canonical:, type:, checksum_valid:)
      if checksum_valid
        NormalizedIdentifier.new(
          original: original,
          normalized: normalized,
          canonical: canonical,
          type: type,
          validation_status: :valid,
          warnings: []
        )
      else
        NormalizedIdentifier.new(
          original: original,
          normalized: normalized,
          canonical: canonical,
          type: type,
          validation_status: :warning,
          warnings: [ "invalid EAN-13 check digit" ]
        )
      end
    end

    def isbn13_range?(value)
      value.start_with?("978", "979")
    end

    def valid_isbn10_check?(body, check)
      sum = 0
      body.each_char.with_index(1) { |char, index| sum += char.to_i * (11 - index) }
      check_value = check == "X" ? 10 : check.to_i
      sum += check_value
      (sum % 11).zero?
    end

    def valid_upc_check?(digits)
      valid_ean13_check?("0#{digits}")
    end

    def valid_ean13_check?(digits)
      return false unless digits.match?(/\A\d{13}\z/)

      expected = ean13_check_digit(digits[0, 12])
      digits[12].to_i == expected
    end

    def ean13_check_digit(twelve_digits)
      sum = twelve_digits.chars.each_with_index.sum do |char, index|
        digit = char.to_i
        index.even? ? digit : digit * 3
      end
      (10 - (sum % 10)) % 10
    end
  end
end
