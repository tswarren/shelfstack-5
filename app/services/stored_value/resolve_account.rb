# frozen_string_literal: true

module StoredValue
  # Resolve a stored-value account from scan/typed input: canonical account
  # number or organization-scoped alternate identifier.
  class ResolveAccount < ApplicationService
    Error = Class.new(StandardError)
    NotFoundError = Class.new(Error)
    AmbiguousError = Class.new(Error)

    Result = Data.define(:account, :matched_on)

    def initialize(organization:, identifier:)
      @organization = organization
      @identifier = identifier.to_s.strip
    end

    def call
      raise Error, "identifier is required" if @identifier.blank?

      candidates = lookup_candidates(@identifier)
      raise NotFoundError, "stored-value account not found" if candidates.empty?

      accounts = candidates.map(&:first).uniq(&:id)
      raise AmbiguousError, "identifier matches multiple stored-value accounts" if accounts.size > 1

      account, matched_on = candidates.first
      Result.new(account: account, matched_on: matched_on)
    end

    private

    def lookup_candidates(raw)
      compact = raw.to_s.strip.gsub(/[\s\-]/, "")
      variants = [ raw, raw.downcase, compact, compact.downcase, digits_only(raw) ].compact_blank.uniq
      found = []

      variants.each do |value|
        by_number = @organization.stored_value_accounts.find_by(account_number: value)
        found << [ by_number, "account_number" ] if by_number

        by_alternate = @organization.stored_value_accounts.find_by(alternate_identifier: value)
        found << [ by_alternate, "alternate_identifier" ] if by_alternate
      end

      found
    end

    def digits_only(value)
      digits = value.gsub(/\D/, "")
      digits.presence
    end
  end
end
