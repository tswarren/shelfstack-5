# frozen_string_literal: true

module Catalog
  module Enrichment
    # Maps provider-supplied creator entries onto the Slice 1 ProductCreator
    # role allowlist. Reuses ProductCreator::ROLES directly rather than
    # duplicating it -- this never redefines the Slice 1 schema contract.
    #
    # provider order -> contiguous zero-based position;
    # missing or unrecognized role -> "contributor" + a NormalizedWarning
    # (arbitrary provider role strings are never persisted).
    class NormalizeCreators < ApplicationService
      def initialize(raw_creators:)
        @raw_creators = Array(raw_creators)
      end

      def call
        warnings = []

        creators = @raw_creators.each_with_index.map do |raw, index|
          hash = raw.respond_to?(:to_h) ? raw.to_h.symbolize_keys : {}
          display_name = hash[:display_name].to_s.strip
          credited_as = hash[:credited_as].to_s.strip.presence
          raw_role = hash[:role]
          role = normalize_role(raw_role)

          if role.nil?
            warnings << unrecognized_role_warning(display_name, raw_role)
            role = "contributor"
          end

          Catalog::Enrichment::NormalizedCreator.new(
            display_name: display_name, role: role, credited_as: credited_as, position: index
          )
        end

        [ creators, warnings ]
      end

      private

      def normalize_role(raw_role)
        role = raw_role.to_s.strip.downcase
        return nil if role.blank?

        ProductCreator::ROLES.include?(role) ? role : nil
      end

      def unrecognized_role_warning(display_name, raw_role)
        Catalog::Enrichment::NormalizedWarning.new(
          code: "creator_role_unrecognized",
          message: "Provider creator role could not be mapped to a known role and was recorded as contributor.",
          details: { display_name: display_name, provider_role: raw_role }
        )
      end
    end
  end
end
