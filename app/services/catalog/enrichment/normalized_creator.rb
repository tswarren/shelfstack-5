# frozen_string_literal: true

module Catalog
  module Enrichment
    # One provider-supplied creator entry, already mapped onto the
    # ProductCreator role allowlist (Slice 1) with a contiguous zero-based
    # `position` derived from the provider's own ordering.
    NormalizedCreator = Data.define(:display_name, :role, :credited_as, :position)
  end
end
