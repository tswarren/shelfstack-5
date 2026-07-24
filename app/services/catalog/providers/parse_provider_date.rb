# frozen_string_literal: true

module Catalog
  module Providers
    # Conservative shared date parser for provider JSON (ISBNdb and Google
    # Books both use plain "YYYY" / "YYYY-MM" / "YYYY-MM-DD..." strings).
    # Returns `[date, precision]` matching the Catalog::PartialPublicationDate
    # contract (year -> Jan 1, month -> day 1, day -> exact date), or
    # `[nil, nil]` for blank/unrecognized input -- never guesses at free text.
    class ParseProviderDate < ApplicationService
      FULL_DATE = /\A(\d{4})-(\d{2})-(\d{2})/
      YEAR_MONTH = /\A(\d{4})-(\d{2})\z/
      YEAR_ONLY = /\A(\d{4})\z/

      def initialize(raw)
        @raw = raw.to_s.strip
      end

      def call
        return [ nil, nil ] if @raw.blank?

        if (match = FULL_DATE.match(@raw))
          return with_date(match[1], match[2], match[3], "day")
        end

        if (match = YEAR_MONTH.match(@raw))
          return with_date(match[1], match[2], "1", "month")
        end

        if (match = YEAR_ONLY.match(@raw))
          return with_date(match[1], "1", "1", "year")
        end

        [ nil, nil ]
      end

      private

      def with_date(year, month, day, precision)
        date = Date.new(year.to_i, month.to_i, day.to_i)
        [ date, precision ]
      rescue ArgumentError
        [ nil, nil ]
      end
    end
  end
end
