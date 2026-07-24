# frozen_string_literal: true

module Catalog
  module Enrichment
    # Sole constructor for Catalog::Enrichment::NormalizedResult. Provider
    # adapters map their own JSON into this factory's plain-hash inputs;
    # nothing downstream depends on ISBNdb- or Google-Books-specific keys.
    #
    # Normalizes creators (role mapping + contiguous position) and list price
    # (BigDecimal, half-up cents, uppercase-or-null currency), then deep-freezes
    # the whole result so callers cannot mutate a "normalized" value after the
    # fact.
    class BuildNormalizedResult < ApplicationService
      def initialize(requested_identifier:, canonical_identifier:, provider:, provider_record_id: nil,
                      retrieved_at: Time.current, title: nil, subtitle: nil, description: nil,
                      creators: [], publisher: nil, imprint: nil, publication_date: nil,
                      language_code: nil, edition_statement: nil, provider_format: nil,
                      external_subjects: [], list_price: nil, images: [], warnings: [])
        @requested_identifier = requested_identifier
        @canonical_identifier = canonical_identifier
        @provider = provider.to_s
        @provider_record_id = provider_record_id
        @retrieved_at = retrieved_at
        @title = title.presence
        @subtitle = subtitle.presence
        @description = description.presence
        @raw_creators = creators
        @publisher = publisher.presence
        @imprint = imprint.presence
        @raw_publication_date = publication_date
        @language_code = language_code.to_s.strip.presence
        @edition_statement = edition_statement.presence
        @provider_format = provider_format.presence
        @raw_external_subjects = external_subjects
        @raw_list_price = list_price
        @raw_images = images
        @raw_warnings = warnings
      end

      def call
        warnings = []

        creators, creator_warnings = Catalog::Enrichment::NormalizeCreators.call(raw_creators: @raw_creators)
        warnings.concat(creator_warnings)

        list_price, money_warnings = normalize_money
        warnings.concat(money_warnings)

        warnings.concat(Array(@raw_warnings).map { |warning| coerce_warning(warning) })

        result = Catalog::Enrichment::NormalizedResult.new(
          requested_identifier: @requested_identifier,
          canonical_identifier: @canonical_identifier,
          provider: @provider,
          provider_record_id: @provider_record_id,
          retrieved_at: @retrieved_at,
          title: @title,
          subtitle: @subtitle,
          description: @description,
          creators: creators,
          publisher: @publisher,
          imprint: @imprint,
          publication_date: normalize_publication_date,
          language_code: @language_code,
          edition_statement: @edition_statement,
          provider_format: @provider_format,
          external_subjects: Array(@raw_external_subjects).map(&:to_s),
          list_price: list_price,
          images: normalize_images,
          warnings: warnings
        )

        Catalog::Enrichment::DeepFreeze.call(result)
      end

      private

      def normalize_publication_date
        return nil if @raw_publication_date.nil?
        return @raw_publication_date if @raw_publication_date.is_a?(Catalog::Enrichment::NormalizedPublicationDate)

        hash = @raw_publication_date.to_h.symbolize_keys
        return nil if hash[:date].blank?

        Catalog::Enrichment::NormalizedPublicationDate.new(date: hash[:date], precision: hash[:precision])
      end

      def normalize_money
        return [ nil, [] ] if @raw_list_price.blank?

        hash = @raw_list_price.respond_to?(:to_h) ? @raw_list_price.to_h.symbolize_keys : {}
        Catalog::Enrichment::NormalizeMoney.call(amount: hash[:amount], currency_code: hash[:currency_code])
      end

      def normalize_images
        Array(@raw_images).map do |image|
          image.respond_to?(:to_h) ? image.to_h.stringify_keys : image.to_s
        end
      end

      def coerce_warning(warning)
        return warning if warning.is_a?(Catalog::Enrichment::NormalizedWarning)

        hash = warning.to_h.symbolize_keys
        Catalog::Enrichment::NormalizedWarning.new(
          code: hash[:code], message: hash[:message], details: hash[:details] || {}
        )
      end
    end
  end
end
