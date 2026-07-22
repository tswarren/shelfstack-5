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
      found = []

      account_variants(raw).each do |value|
        by_number = @organization.stored_value_accounts.find_by(account_number: value)
        found << [ by_number, "account_number" ] if by_number
      end

      alternate = StoredValueAccount.normalize_alternate_identifier(raw)
      if alternate.present?
        by_alternate = @organization.stored_value_accounts.find_by(alternate_identifier: alternate)
        found << [ by_alternate, "alternate_identifier" ] if by_alternate
      end

      found
    end

    def account_variants(raw)
      compact = raw.to_s.strip.gsub(/[\s\-]/, "")
      [ raw, raw.downcase, compact, compact.downcase, digits_only(raw) ].compact_blank.uniq
    end

    def digits_only(value)
      digits = value.gsub(/\D/, "")
      digits.presence
    end
  end
end
