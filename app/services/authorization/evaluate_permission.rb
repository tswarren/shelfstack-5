# frozen_string_literal: true

module Authorization
  # Returns :allow or :deny for a permission key in store context.
  # Never branches on role name or role code.
  class EvaluatePermission < ApplicationService
    def initialize(user:, store:, permission_key:)
      @user = user
      @store = store
      @permission_key = permission_key.to_s
    end

    def call
      return :deny unless @user&.active?
      return :deny if @user.locked?
      return :deny unless @store&.active?

      membership = StoreMembership.find_by(user_id: @user.id, store_id: @store.id)
      return :deny unless membership&.effective_on?

      role = membership.role
      return :deny unless role&.active?

      permission = Permission.find_by(code: @permission_key, active: true)
      return :deny unless permission

      return :deny unless RolePermission.exists?(role_id: role.id, permission_id: permission.id)

      :allow
    end
  end
end
