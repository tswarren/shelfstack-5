# frozen_string_literal: true

module Catalog
  module Enrichment
    # Same partial-date contract as Catalog::PartialPublicationDate (Slice 1):
    # `date` is always a complete Y-M-D value; `precision` records how much
    # of it the provider actually asserted (year -> Jan 1, month -> day 1,
    # day -> exact date).
    NormalizedPublicationDate = Data.define(:date, :precision)
  end
end
