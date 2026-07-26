# frozen_string_literal: true

require "phonelib"

module Customers
  # Parses phone input to E.164 using phonelib.
  # Country resolution: explicit + prefix → customer_country → default_country (store).
  # Leading + is never reinterpreted by customer/store country.
  class NormalizePhone < ApplicationService
    Error = Class.new(StandardError)

    REMEDY = "Enter a valid phone number, including the country code when the " \
             "number is outside Canada or the United States."

    def initialize(raw, customer_country: nil, default_country: nil)
      @raw = raw
      @customer_country = customer_country.to_s.strip.upcase.presence
      @default_country = default_country.to_s.strip.upcase.presence
    end

    def call
      return nil if @raw.blank?

      trimmed = @raw.to_s.strip
      return nil if trimmed.blank?

      if trimmed.start_with?("+")
        phone = ::Phonelib.parse(trimmed)
      else
        country = @customer_country || @default_country
        phone = country.present? ? ::Phonelib.parse(trimmed, country) : ::Phonelib.parse(trimmed)
      end

      unless phone.valid?
        raise Error, REMEDY
      end

      phone.e164.presence || (raise Error, REMEDY)
    end
  end
end
