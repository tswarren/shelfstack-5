# frozen_string_literal: true

module Authorization
  # Evaluates numeric authority using membership overrides only (OD-013 interim).
  # Null override => deny as unconfigured. requires_approval is informational.
  class EvaluateAuthority < ApplicationService
    def initialize(user:, store:, limit_key:, requested_value:)
      @user = user
      @store = store
      @limit_key = limit_key.to_sym
      @requested_value = requested_value
    end

    def call
      unless AuthorityLimits.known?(@limit_key)
        return result(:deny, configured_limit: nil, source: :unknown_limit_key)
      end

      return result(:deny, configured_limit: nil, source: :inactive_principal) unless @user&.active? && !@user.locked?
      return result(:deny, configured_limit: nil, source: :inactive_principal) unless @store&.active?

      membership = StoreMembership.find_by(user_id: @user.id, store_id: @store.id)
      unless membership&.effective_on?
        return result(:deny, configured_limit: nil, source: :no_effective_membership)
      end

      column = AuthorityLimits.definition_for(@limit_key)[:column]
      configured = membership.public_send(column)

      if configured.nil?
        return result(:deny, configured_limit: nil, source: :unconfigured)
      end

      if BigDecimal(@requested_value.to_s) <= BigDecimal(configured.to_s)
        result(:allow, configured_limit: configured, source: :store_membership)
      else
        result(:requires_approval, configured_limit: configured, source: :store_membership)
      end
    end

    private

    def result(status, configured_limit:, source:)
      AuthorityResult.new(
        status: status,
        limit_key: @limit_key,
        requested_value: @requested_value,
        configured_limit: configured_limit,
        source: source
      )
    end
  end
end
