# frozen_string_literal: true

module Customers
  # Org-scoped Customer search. Active-by-default; direct customer_number may
  # return inactive with include_inactive_by_number.
  class Search < ApplicationService
    Result = Data.define(:customers, :inactive_direct_match)

    def initialize(organization:, query:, include_inactive: false, limit: 25)
      @organization = organization
      @query = query.to_s.strip
      @include_inactive = include_inactive
      @limit = limit
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
      phone_digits = @query.gsub(/[^\d+]/, "")

      scope = scope.where(
        <<~SQL.squish,
          first_name ILIKE :q
          OR last_name ILIKE :q
          OR organization_name ILIKE :q
          OR concat_ws(' ', first_name, last_name) ILIKE :q
          OR primary_email ILIKE :q
          OR alternate_email ILIKE :q
          OR customer_number = :exact
          OR primary_phone = :phone
          OR alternate_phone = :phone
          OR primary_phone ILIKE :q
          OR alternate_phone ILIKE :q
        SQL
        q: pattern,
        exact: @query,
        phone: phone_digits.presence || @query
      ).order(:last_name, :first_name, :organization_name).limit(@limit)

      Result.new(customers: scope.to_a, inactive_direct_match: nil)
    end
  end
end
