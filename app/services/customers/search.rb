# frozen_string_literal: true

module Customers
  # Org-scoped Customer search. Active-by-default; direct customer_number may
  # return inactive with an inactive_direct_match warning.
  class Search < ApplicationService
    Result = Data.define(:customers, :inactive_direct_match)

    def initialize(organization:, query:, include_inactive: false, limit: 25, default_phone_country: nil)
      @organization = organization
      @query = query.to_s.strip
      @include_inactive = include_inactive
      @limit = limit
      @default_phone_country = default_phone_country.to_s.strip.upcase.presence
    end

    def call
      return Result.new(customers: [], inactive_direct_match: nil) if @query.blank?

      digits = @query.gsub(/\D/, "")
      if digits.length == 13 && digits.start_with?("22")
        direct = @organization.customers.find_by(customer_number: digits)
        if direct
          if direct.active? || @include_inactive
            return Result.new(customers: [ direct ], inactive_direct_match: (direct.active? ? nil : direct))
          end
          return Result.new(customers: [ direct ], inactive_direct_match: direct)
        end
      end

      scope = @organization.customers
      scope = scope.active unless @include_inactive

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      e164 = normalize_query_phone

      scope = scope.where(
        <<~SQL.squish,
          first_name ILIKE :q
          OR last_name ILIKE :q
          OR organization_name ILIKE :q
          OR concat_ws(' ', first_name, last_name) ILIKE :q
          OR primary_email ILIKE :q
          OR alternate_email ILIKE :q
          OR customer_number = :exact
          OR primary_phone = :e164
          OR alternate_phone = :e164
        SQL
        q: pattern,
        exact: @query,
        e164: e164
      ).order(:last_name, :first_name, :organization_name).limit(@limit)

      Result.new(customers: scope.to_a, inactive_direct_match: nil)
    end

    private

    # Best-effort E.164 for phone-shaped queries. Invalid input is ignored so
    # name/email/number search still runs. Try store country first, then CA/US
    # so common NANP formats still match across nearby defaults.
    def normalize_query_phone
      return nil unless @query.match?(/\d/)

      countries = [ @default_phone_country, "CA", "US" ].compact.uniq
      countries.each do |country|
        return NormalizePhone.call(@query, default_country: country)
      rescue NormalizePhone::Error
        next
      end

      return NormalizePhone.call(@query) if @query.start_with?("+")

      nil
    rescue NormalizePhone::Error
      nil
    end
  end
end
