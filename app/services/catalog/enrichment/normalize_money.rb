# frozen_string_literal: true

require "bigdecimal"

module Catalog
  module Enrichment
    # Parses a provider-supplied list price with decimal arithmetic only --
    # never Float. Rejects negative or non-numeric amounts. Rounds to integer
    # cents with one documented rule (half up). Currency codes are uppercased;
    # an absent currency stays nil rather than being assumed here (OD-P8-01 §5
    # assumption/preview policy belongs to the later create/enrich workflow).
    class NormalizeMoney < ApplicationService
      def initialize(amount:, currency_code: nil)
        @amount = amount
        @currency_code = currency_code
      end

      def call
        return [ nil, [] ] if @amount.blank?

        decimal = to_decimal(@amount)
        return [ nil, [ invalid_amount_warning ] ] if decimal.nil? || decimal.negative?

        cents = (decimal * 100).round(0, half: :up).to_i
        money = Catalog::Enrichment::NormalizedMoney.new(amount_cents: cents, currency_code: normalized_currency)
        [ money, [] ]
      end

      private

      def to_decimal(value)
        case value
        when BigDecimal
          value
        when Numeric
          BigDecimal(value.to_s)
        when String
          cleaned = value.strip
          return nil if cleaned.blank?

          BigDecimal(cleaned)
        end
      rescue ArgumentError, TypeError
        nil
      end

      def normalized_currency
        @currency_code.to_s.strip.upcase.presence
      end

      def invalid_amount_warning
        Catalog::Enrichment::NormalizedWarning.new(
          code: "invalid_list_price",
          message: "Provider list price could not be parsed as a non-negative amount and was discarded.",
          details: { raw_amount: @amount, raw_currency_code: @currency_code }
        )
      end
    end
  end
end
