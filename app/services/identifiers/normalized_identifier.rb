# frozen_string_literal: true

module Identifiers
  NormalizedIdentifier = Data.define(
    :original,
    :normalized,
    :canonical,
    :type,
    :validation_status,
    :warnings
  )
end
