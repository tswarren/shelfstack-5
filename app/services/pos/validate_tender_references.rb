# frozen_string_literal: true

module Pos
  # Normalizes and enforces TenderType reference_1 / reference_2 rules.
  # Persistence mapping: authorization_code ← reference 1, terminal_reference ← reference 2.
  class ValidateTenderReferences < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:authorization_code, :terminal_reference, :reference_1, :reference_2)

    def initialize(tender_type:, reference_1: nil, reference_2: nil,
                   authorization_code: nil, terminal_reference: nil)
      @tender_type = tender_type
      @reference_1 = coalesce(reference_1, authorization_code)
      @reference_2 = coalesce(reference_2, terminal_reference)
    end

    def call
      ref1 = normalize(@reference_1)
      ref2 = normalize(@reference_2)

      enforce!(
        requirement: @tender_type.reference_1_requirement,
        value: ref1,
        label: @tender_type.reference_1_label.presence || "Reference 1",
        mask: @tender_type.reference_1_mask
      )
      enforce!(
        requirement: @tender_type.reference_2_requirement,
        value: ref2,
        label: @tender_type.reference_2_label.presence || "Reference 2",
        mask: @tender_type.reference_2_mask
      )

      Result.new(
        authorization_code: ref1,
        terminal_reference: ref2,
        reference_1: ref1,
        reference_2: ref2
      )
    end

    private

    def coalesce(primary, fallback)
      primary.nil? ? fallback : primary
    end

    def normalize(value)
      value.to_s.strip.presence
    end

    def enforce!(requirement:, value:, label:, mask:)
      case requirement.to_s
      when "required"
        raise Error, "#{label} is required" if value.blank?
      when "optional", "none"
        # none: still accept blank; optional: blank allowed
      else
        raise Error, "unknown reference requirement #{requirement.inspect}"
      end

      return if value.blank? || mask.blank?

      pattern = Regexp.new("\\A#{mask}\\z")
      raise Error, "#{label} does not match required format" unless value.match?(pattern)
    rescue RegexpError
      raise Error, "#{label} mask is invalid"
    end
  end
end
