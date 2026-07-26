# frozen_string_literal: true

module Customers
  # Application-level email normalization: trim + lowercase.
  # Deliberate ShelfStack policy; not claimed as an RFC mandate.
  # Does not apply provider-specific rewriting.
  class NormalizeEmail < ApplicationService
    def initialize(raw)
      @raw = raw
    end

    def call
      return nil if @raw.blank?

      @raw.to_s.strip.downcase.presence
    end
  end
end
