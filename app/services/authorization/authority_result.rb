# frozen_string_literal: true

module Authorization
  AuthorityResult = Data.define(:status, :limit_key, :requested_value, :configured_limit, :source) do
    def allow?
      status == :allow
    end

    def deny?
      status == :deny
    end

    def requires_approval?
      status == :requires_approval
    end

    # Phase 1: both deny and requires_approval mean do not perform the action.
    def proceed?
      allow?
    end
  end
end
