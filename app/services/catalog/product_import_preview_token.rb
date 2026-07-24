# frozen_string_literal: true

module Catalog
  # Short-lived signed preview state for create-from-ISBN accept (Gate 8c
  # review hardening). Immutable provider provenance and Creator suggestions
  # are taken only from a verified token — never from editable/hidden form
  # fields alone.
  class ProductImportPreviewToken
    Error = Class.new(StandardError)
    ExpiredError = Class.new(Error)
    InvalidError = Class.new(Error)
    CreatorResolutionError = Class.new(Error)

    PURPOSE = "catalog.product_import_preview"
    TTL = 30.minutes

    def self.issue(organization:, actor:, normalized_result:, warnings: [], creator_suggestions: [])
      new(organization: organization, actor: actor).issue(
        normalized_result: normalized_result,
        warnings: warnings,
        creator_suggestions: creator_suggestions
      )
    end

    def self.verify!(token:, organization:, actor:)
      new(organization: organization, actor: actor).verify!(token)
    end

    def self.resolve_creator_resolutions!(payload:, submitted:)
      claims = Array(payload.is_a?(Hash) ? payload.stringify_keys["creator_suggestions"] : nil)
      rows = Array(submitted)

      if rows.size != claims.size
        raise CreatorResolutionError,
              "Creator assignments must match the signed preview (#{claims.size} expected, #{rows.size} submitted)."
      end

      claims.each_with_index.map do |claim, index|
        claim = claim.stringify_keys
        row = rows[index].respond_to?(:to_h) ? rows[index].to_h.symbolize_keys : {}
        build_resolution_from_claim!(claim, row)
      end
    end

    def self.build_resolution_from_claim!(claim, row)
      role = claim["role"].presence || "contributor"
      credited_as = claim["credited_as"]

      case claim["resolution"].to_s
      when "propose_create"
        {
          action: "create",
          display_name: claim["display_name"],
          role: role,
          credited_as: credited_as
        }
      when "suggest_existing"
        matched = claim["matched_creator_id"]
        if matched.blank?
          raise CreatorResolutionError, "Signed preview is missing a matched creator."
        end

        {
          action: "use_existing",
          creator_id: matched.to_i,
          role: role,
          credited_as: credited_as
        }
      when "require_selection"
        selected = row[:creator_id].presence
        allowed = Array(claim["candidate_creator_ids"]).map(&:to_i)
        unless selected.present? && allowed.include?(selected.to_i)
          raise CreatorResolutionError,
                "Selected creator is not among the signed candidates for #{claim["display_name"]}."
        end

        {
          action: "use_existing",
          creator_id: selected.to_i,
          role: role,
          credited_as: credited_as
        }
      else
        raise CreatorResolutionError, "Signed preview has an unknown creator resolution."
      end
    end
    private_class_method :build_resolution_from_claim!

    def initialize(organization:, actor:)
      @organization = organization
      @actor = actor
    end

    def issue(normalized_result:, warnings: [], creator_suggestions: [])
      money = normalized_result.list_price
      payload = {
        "organization_id" => @organization.id,
        "actor_user_id" => @actor.id,
        "exp" => TTL.from_now.to_i,
        "provider" => normalized_result.provider.to_s,
        "provider_record_id" => normalized_result.provider_record_id,
        "requested_identifier" => normalized_result.requested_identifier.to_s,
        "canonical_identifier" => normalized_result.canonical_identifier.to_s,
        "retrieved_at" => normalized_result.retrieved_at&.iso8601,
        "accepted_warnings" => normalize_warnings(warnings),
        "list_price_cents" => money&.amount_cents,
        "list_price_currency_code" => money&.currency_code,
        "creator_suggestions" => normalize_creator_suggestions(creator_suggestions)
      }
      verifier.generate(payload, purpose: PURPOSE)
    end

    def verify!(token)
      raise InvalidError, "Preview session is missing or invalid." if token.blank?

      payload = verifier.verify(token, purpose: PURPOSE)
      raise InvalidError, "Preview session is invalid." unless payload.is_a?(Hash)

      payload = payload.stringify_keys
      assert_binding!(payload)
      assert_fresh!(payload)
      payload
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise InvalidError, "Preview session is invalid or has been tampered with."
    end

    private

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end

    def assert_binding!(payload)
      unless payload["organization_id"].to_i == @organization.id
        raise InvalidError, "Preview session does not belong to this organization."
      end
      unless payload["actor_user_id"].to_i == @actor.id
        raise InvalidError, "Preview session does not belong to this user."
      end
    end

    def assert_fresh!(payload)
      exp = payload["exp"].to_i
      raise ExpiredError, "Preview session has expired. Look up the ISBN again." if exp <= Time.current.to_i
    end

    def normalize_warnings(warnings)
      Array(warnings).map do |warning|
        if warning.respond_to?(:code)
          { "code" => warning.code, "message" => warning.message, "details" => warning.details }.compact
        else
          hash = warning.respond_to?(:to_h) ? warning.to_h : warning
          hash.stringify_keys.slice("code", "message", "details")
        end
      end
    end

    def normalize_creator_suggestions(suggestions)
      Array(suggestions).map.with_index do |suggestion, index|
        {
          "position" => suggestion.respond_to?(:position) ? suggestion.position : index,
          "display_name" => suggestion.display_name.to_s,
          "role" => suggestion.role.to_s,
          "credited_as" => suggestion.credited_as,
          "resolution" => suggestion.resolution.to_s,
          "matched_creator_id" => suggestion.matched_creator_id,
          "candidate_creator_ids" => Array(suggestion.candidate_creator_ids).map(&:to_i)
        }
      end
    end
  end
end
