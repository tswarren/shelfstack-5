# frozen_string_literal: true

module Catalog
  module Enrichment
    # Provider-neutral normalized bibliographic result (Gate 8b Slice 2).
    # Both ISBNdb and Google Books adapters produce this same immutable
    # contract; application code must never branch on provider-specific
    # response shapes. Build only through Catalog::Enrichment::BuildNormalizedResult
    # (validates and deep-freezes nested collections).
    NormalizedResult = Data.define(
      :requested_identifier, :canonical_identifier, :provider, :provider_record_id, :retrieved_at,
      :title, :subtitle, :description, :creators, :publisher, :imprint,
      :publication_date, :language_code, :edition_statement,
      :provider_format, :external_subjects, :list_price, :images, :warnings
    )
  end
end
