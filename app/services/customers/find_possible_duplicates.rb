# frozen_string_literal: true

module Customers
  # Searches across primary and alternate phone/email for possible duplicates.
  # Non-blocking — callers decide whether to warn before create.
  class FindPossibleDuplicates < ApplicationService
    Result = Data.define(:customers)

    def initialize(organization:, attributes:, excluding_id: nil)
      @organization = organization
      @attributes = attributes.stringify_keys
      @excluding_id = excluding_id
    end

    def call
      scope = @organization.customers
      scope = scope.where.not(id: @excluding_id) if @excluding_id

      phones = [ @attributes["primary_phone"], @attributes["alternate_phone"] ].compact_blank.uniq
      emails = [ @attributes["primary_email"], @attributes["alternate_email"] ].compact_blank.uniq

      matches = []
      if phones.any?
        matches.concat(
          scope.where(primary_phone: phones)
            .or(scope.where(alternate_phone: phones))
            .to_a
        )
      end
      if emails.any?
        matches.concat(
          scope.where(primary_email: emails)
            .or(scope.where(alternate_email: emails))
            .to_a
        )
      end

      Result.new(customers: matches.uniq(&:id))
    end
  end
end
