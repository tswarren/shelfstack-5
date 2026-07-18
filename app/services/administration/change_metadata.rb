# frozen_string_literal: true

module Administration
  # Builds sanitized before/after snapshots for administrative audit metadata.
  module ChangeMetadata
    SENSITIVE_ATTRIBUTES = %w[
      password
      password_confirmation
      password_digest
      pin
      pin_confirmation
      pin_digest
    ].freeze

    module_function

    def snapshot(record, attributes)
      attributes.each_with_object({}) do |attribute, hash|
        key = attribute.to_s
        next if SENSITIVE_ATTRIBUTES.include?(key)

        hash[key] = serialize(record.public_send(attribute))
      end
    end

    def diff(before, after)
      keys = (before.keys | after.keys).select { |key| before[key] != after[key] }
      return {} if keys.empty?

      {
        "before" => before.slice(*keys),
        "after" => after.slice(*keys)
      }
    end

    def serialize(value)
      case value
      when BigDecimal then value.to_s("F")
      when Date, Time, ActiveSupport::TimeWithZone then value.iso8601
      else value
      end
    end
  end
end
