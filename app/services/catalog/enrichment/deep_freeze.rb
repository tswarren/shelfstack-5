# frozen_string_literal: true

module Catalog
  module Enrichment
    # `Data.define` instances freeze themselves on construction, but that
    # freeze is shallow -- a Hash held in a Data field (e.g. NormalizedWarning#details)
    # is not itself frozen, and arrays of Data instances (NormalizedResult#creators,
    # #warnings, etc.) are not frozen containers. Recursively freezes Array/Hash/String
    # values and walks into nested Data objects so the whole NormalizedResult graph is
    # immutable end to end.
    module DeepFreeze
      module_function

      def call(value)
        case value
        when Array
          value.each { |item| call(item) }
          value.freeze
        when Hash
          value.each { |k, v| call(k); call(v) }
          value.freeze
        when String
          value.freeze
        when Data
          value.class.members.each { |member| call(value.public_send(member)) }
          value.freeze
        else
          value
        end
      end
    end
  end
end
