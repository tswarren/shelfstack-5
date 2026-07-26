# frozen_string_literal: true

module Catalog
  module Providers
    # Conservative shared date parser for provider JSON. Persists only exact
    # calendar days (YYYY-MM-DD…). Year-only / month-only strings return nil —
    # ShelfStack does not invent Jan 1 / day-1 placeholders (OD-P8-10 revision).
    class ParseProviderDate < ApplicationService
      FULL_DATE = /\A(\d{4})-(\d{2})-(\d{2})(?:\D|\z)/

      def initialize(raw)
        @raw = raw.to_s.strip
      end

      def call
        return nil if @raw.blank?

        match = FULL_DATE.match(@raw)
        return nil unless match

        Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
      rescue ArgumentError
        nil
      end
    end
  end
end
