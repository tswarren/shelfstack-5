# frozen_string_literal: true

module Catalog
  # Conservative provider-format mapping boundary (Gate 8b Slice 2, OD-P8-01
  # §3 "Merchandise class and format suggestions"). Suggests only when
  # exactly one active Product Format matches by exact code/name, or a small
  # explicit token map uniquely resolves the provider string to one. Multiple
  # matches -> no suggestion + warning. Never creates, updates, or
  # auto-applies a Product Format -- read-only lookup only.
  class MapProductFormat < ApplicationService
    FormatSuggestion = Data.define(:product_format, :warning)

    # Deliberately small and explicit -- provider format strings vary widely
    # across sources, and a broad fuzzy dictionary would guess wrong more
    # than it would help (OD-P8-01 decision note).
    TOKEN_MAP = {
      "hardback" => "hardcover",
      "hb" => "hardcover",
      "softcover" => "paperback",
      "trade paperback" => "paperback",
      "paperback book" => "paperback",
      "mass market" => "mass_market_paperback",
      "mass market paperback" => "mass_market_paperback",
      "ebook" => "ebook",
      "e-book" => "ebook",
      "digital" => "ebook",
      "audiobook" => "audiobook",
      "audio book" => "audiobook",
      "compact disc" => "audiobook"
    }.freeze

    def initialize(organization:, provider_format:)
      @organization = organization
      @provider_format = provider_format
    end

    def call
      normalized = normalize(@provider_format)
      return no_suggestion if normalized.blank?

      matches = active_formats.select { |format| exact_match?(format, normalized) }

      case matches.size
      when 0 then no_suggestion
      when 1 then FormatSuggestion.new(product_format: matches.first, warning: nil)
      else FormatSuggestion.new(product_format: nil, warning: ambiguous_warning(matches))
      end
    end

    private

    def normalize(value)
      value.to_s.strip.downcase.gsub(/[\s_-]+/, " ")
    end

    def active_formats
      @active_formats ||= @organization.product_formats.where(active: true).to_a
    end

    def exact_match?(format, normalized)
      return true if normalize(format.code) == normalized
      return true if normalize(format.name) == normalized

      token_code = TOKEN_MAP[normalized]
      token_code.present? && normalize(format.code) == normalize(token_code)
    end

    def no_suggestion
      FormatSuggestion.new(product_format: nil, warning: nil)
    end

    def ambiguous_warning(matches)
      Catalog::Enrichment::NormalizedWarning.new(
        code: "ambiguous_product_format",
        message: "Provider format #{@provider_format.inspect} matched more than one active product format.",
        details: { candidate_product_format_ids: matches.map(&:id) }
      )
    end
  end
end
