# frozen_string_literal: true

module Catalog
  # Bibliographic partial-date contract (OD-P8-10). SQL `date` always stores a
  # complete Y-M-D value; `precision` records how much of that date the
  # source actually asserted:
  #
  #   precision = year  -> publication_date = YYYY-01-01
  #   precision = month -> publication_date = YYYY-MM-01
  #   precision = day   -> exact date
  #
  # Used both to validate already-assigned (date, precision) pairs (Product
  # model validation) and to build a full date from separate UI parts so the
  # product form never relies on a lone HTML date input for year/month
  # precision.
  class PartialPublicationDate
    PRECISIONS = %w[year month day].freeze

    Result = Data.define(:date, :precision, :errors) do
      def valid? = errors.empty?
    end

    class << self
      # Validate an already-assigned (date, precision) pair.
      def validate(date:, precision:)
        precision = precision.presence

        return Result.new(date: nil, precision: nil, errors: []) if date.blank? && precision.blank?

        if date.blank? || precision.blank?
          return Result.new(date: date, precision: precision,
            errors: [ "publication date and precision must both be present or both be blank" ])
        end

        unless PRECISIONS.include?(precision.to_s)
          return Result.new(date: date, precision: precision,
            errors: [ "publication_date_precision must be one of #{PRECISIONS.join(', ')}" ])
        end

        parsed = as_date(date)
        if parsed.nil?
          return Result.new(date: date, precision: precision, errors: [ "publication_date is not a valid date" ])
        end

        Result.new(date: parsed, precision: precision.to_s, errors: precision_errors(parsed, precision.to_s))
      end

      # Build a full date from separate year/month/day parts (product form).
      # Unused parts for the given precision are ignored (e.g. day is ignored
      # when precision is "month").
      def parse_parts(precision:, year:, month:, day:)
        precision = precision.to_s.presence

        if precision.blank?
          return Result.new(date: nil, precision: nil, errors: []) if year.blank? && month.blank? && day.blank?
          return Result.new(date: nil, precision: nil, errors: [ "publication_date_precision is required" ])
        end

        unless PRECISIONS.include?(precision)
          return Result.new(date: nil, precision: precision,
            errors: [ "publication_date_precision must be one of #{PRECISIONS.join(', ')}" ])
        end

        year_i = integer_or_nil(year)
        return Result.new(date: nil, precision: precision, errors: [ "publication date year is required" ]) if year_i.nil?

        month_i = precision == "year" ? 1 : integer_or_nil(month)
        if precision != "year" && month_i.nil?
          return Result.new(date: nil, precision: precision, errors: [ "publication date month is required" ])
        end

        day_i = precision == "day" ? integer_or_nil(day) : 1
        if precision == "day" && day_i.nil?
          return Result.new(date: nil, precision: precision, errors: [ "publication date day is required" ])
        end

        begin
          Result.new(date: Date.new(year_i, month_i, day_i), precision: precision, errors: [])
        rescue ArgumentError
          Result.new(date: nil, precision: precision, errors: [ "publication_date is not a valid date" ])
        end
      end

      private

      def integer_or_nil(value)
        return nil if value.blank?

        Integer(value.to_s.strip)
      rescue ArgumentError, TypeError
        nil
      end

      def as_date(value)
        return value if value.is_a?(Date)

        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def precision_errors(date, precision)
        case precision
        when "year"
          date.month == 1 && date.day == 1 ? [] : [ "year precision requires January 1" ]
        when "month"
          date.day == 1 ? [] : [ "month precision requires day 1" ]
        else
          []
        end
      end
    end
  end
end
