# frozen_string_literal: true

module Catalog
  # Short-lived signed preview state for create-from-ISBN accept (Gate 8c
  # review hardening). Immutable provider provenance is taken only from a
  # verified token — never from editable/hidden form fields alone.
  class ProductImportPreviewToken
    Error = Class.new(StandardError)
    ExpiredError = Class.new(Error)
    InvalidError = Class.new(Error)

    PURPOSE = "catalog.product_import_preview"
    TTL = 30.minutes

    def self.issue(organization:, actor:, normalized_result:, warnings: [])
      new(organization: organization, actor: actor).issue(
        normalized_result: normalized_result, warnings: warnings
      )
    end

    def self.verify!(token:, organization:, actor:)
      new(organization: organization, actor: actor).verify!(token)
    end

    def initialize(organization:, actor:)
      @organization = organization
      @actor = actor
    end

    def issue(normalized_result:, warnings: [])
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
        "list_price_currency_code" => money&.currency_code
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
  end
end
