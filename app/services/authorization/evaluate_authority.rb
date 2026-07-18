# frozen_string_literal: true

module Authorization
  # Evaluates numeric authority using membership overrides only (OD-013 interim).
  # Null override => deny as unconfigured. requires_approval is informational.
  # Fail-closed on inactive principals/roles and malformed requested values.
  class EvaluateAuthority < ApplicationService
    def initialize(user:, store:, limit_key:, requested_value:)
      @user = user
      @store = store
      @limit_key = limit_key
      @requested_value = requested_value
    end

    def call
      normalized_key = normalize_limit_key
      return result(:deny, configured_limit: nil, source: :unknown_limit_key, limit_key: normalized_key) if normalized_key.nil?
      return result(:deny, configured_limit: nil, source: :unknown_limit_key, limit_key: normalized_key) unless AuthorityLimits.known?(normalized_key)

      @limit_key = normalized_key
      definition = AuthorityLimits.definition_for(@limit_key)

      return result(:deny, configured_limit: nil, source: :inactive_principal) unless @user&.active? && !@user.locked?
      return result(:deny, configured_limit: nil, source: :inactive_principal) unless @store&.active?

      membership = StoreMembership.find_by(user_id: @user.id, store_id: @store.id)
      unless membership&.effective_on?
        return result(:deny, configured_limit: nil, source: :no_effective_membership)
      end

      role = membership.role
      return result(:deny, configured_limit: nil, source: :inactive_role) unless role&.active?

      requested = parse_requested_value(definition[:type])
      if requested.nil?
        return result(:deny, configured_limit: nil, source: :invalid_requested_value)
      end

      configured = membership.public_send(definition[:column])

      if configured.nil?
        return result(:deny, configured_limit: nil, source: :unconfigured)
      end

      if requested <= BigDecimal(configured.to_s)
        result(:allow, configured_limit: configured, source: :store_membership)
      else
        result(:requires_approval, configured_limit: configured, source: :store_membership)
      end
    end

    private

    def normalize_limit_key
      return nil if @limit_key.nil?
      return @limit_key if @limit_key.is_a?(Symbol)
      return nil if @limit_key.to_s.strip.empty?

      @limit_key.to_s.to_sym
    rescue NoMethodError, TypeError
      nil
    end

    def parse_requested_value(type)
      return nil if @requested_value.nil?
      return nil if @requested_value.is_a?(String) && @requested_value.strip.empty?

      value = BigDecimal(@requested_value.to_s)
      return nil if value.nan? || value.infinite?
      return nil if value.negative?

      case type
      when :rate
        return nil if value > 1
      when :money
        return nil unless value.frac.zero?
      else
        return nil
      end

      value
    rescue ArgumentError, TypeError
      nil
    end

    def result(status, configured_limit:, source:, limit_key: @limit_key)
      AuthorityResult.new(
        status: status,
        limit_key: limit_key,
        requested_value: @requested_value,
        configured_limit: configured_limit,
        source: source
      )
    end
  end
end
