# frozen_string_literal: true

module Catalog
  module Enrichment
    # Non-blocking note attached to a NormalizedResult (Gate 8b plan, Slice 2
    # "Typed normalized result"). `details` is a free-form Hash carrying
    # non-sensitive context only -- never credentials.
    NormalizedWarning = Data.define(:code, :message, :details)
  end
end
