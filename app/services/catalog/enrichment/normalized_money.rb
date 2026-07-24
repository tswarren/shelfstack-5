# frozen_string_literal: true

module Catalog
  module Enrichment
    # Integer cents, never a Float. `currency_code` is uppercase or nil --
    # a nil currency is preserved (not assumed) for later preview policy
    # (OD-P8-01 §5); this value object does not compare against an
    # organization's operating currency.
    NormalizedMoney = Data.define(:amount_cents, :currency_code)
  end
end
