# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    before_action :require_store_context
    helper_method :current_user, :effective_memberships_for
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      skip_before_action :require_store_context, **options
    end

    def skip_store_context(**options)
      skip_before_action :require_store_context, **options
    end
  end

  private

  def current_user
    Current.user
  end

  def require_authentication
    user = User.find_by(id: session[:user_id])
    unless user&.active? && !user.locked?
      Current.reset
      request_authentication
      return
    end

    Current.user = user
  end

  def require_store_context
    return if performed?

    membership = effective_membership_for(Current.user, session[:store_id])
    if membership
      set_current_from_membership(Current.user, membership)
      return
    end

    session.delete(:store_id)
    Current.store = nil
    Current.organization = nil

    memberships = effective_memberships_for(Current.user)
    if memberships.empty?
      redirect_to no_store_access_path
    elsif memberships.one?
      membership = memberships.first
      session[:store_id] = membership.store_id
      set_current_from_membership(Current.user, membership)
    else
      redirect_to new_store_selection_path
    end
  end

  def set_current_from_membership(user, membership)
    Current.user = user
    Current.store = membership.store
    Current.organization = membership.store.organization
    Current.store_membership = membership
    Current.permission_codes = preload_permission_codes(membership)
  end

  # One query for the active permission codes granted by the membership role.
  # Sidebar helpers use Current.permission? — not repeated EvaluatePermission calls.
  def preload_permission_codes(membership)
    return Set.new if membership.blank?

    role = membership.role
    return Set.new unless role&.active?

    Permission
      .joins(:role_permissions)
      .where(role_permissions: { role_id: role.id }, active: true)
      .pluck(:code)
      .to_set
  end

  def effective_membership_for(user, store_id)
    return nil if user.blank? || store_id.blank?

    membership = user.store_memberships.includes(:store, :role).find_by(store_id: store_id)
    return nil unless membership&.effective_on?
    return nil unless membership.store.active?

    membership
  end

  def effective_memberships_for(user)
    return [] if user.blank?

    user.store_memberships.includes(:store).select { |m| m.effective_on? && m.store.active? }
  end

  def request_authentication
    path = internal_redirect_path(request.fullpath)
    session[:return_to_after_authenticating] = path if path.present? && path != new_session_path
    redirect_to new_session_path
  end

  def start_new_session_for(user)
    return_to = session[:return_to_after_authenticating]
    reset_session
    session[:user_id] = user.id
    session[:return_to_after_authenticating] = return_to if return_to.present?
    assign_initial_store!(user)
  end

  # Only relative internal paths are restored after authentication.
  def internal_redirect_path(candidate)
    return nil if candidate.blank?

    uri = URI.parse(candidate.to_s)
    return nil if uri.host.present? && uri.host != request.host
    return nil unless uri.path&.start_with?("/")
    return nil if uri.path.start_with?("//")

    path = uri.path
    path += "?#{uri.query}" if uri.query.present?
    path
  rescue URI::InvalidURIError
    nil
  end

  def assign_initial_store!(user)
    memberships = effective_memberships_for(user)
    if memberships.empty?
      session.delete(:store_id)
      return
    end

    if user.default_store_id.present?
      preferred = memberships.find { |m| m.store_id == user.default_store_id }
      if preferred
        session[:store_id] = preferred.store_id
        return
      end
    end

    if memberships.one?
      session[:store_id] = memberships.first.store_id
    else
      session.delete(:store_id)
    end
  end

  def terminate_session
    reset_session
    Current.reset
  end

  def require_permission!(permission_key)
    unless Current.user&.can?(permission_key, store: Current.store)
      redirect_to root_path, alert: "You are not authorized to perform that action."
    end
  end
end
