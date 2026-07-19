# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :organization, :store, :store_membership, :permission_codes

  # Navigation-only permission check against the request-scoped preloaded set.
  # Controllers must continue to authorize via require_permission! / EvaluatePermission.
  def self.permission?(code)
    codes = permission_codes
    return false if codes.blank?

    codes.include?(code.to_s)
  end
end
