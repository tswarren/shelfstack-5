# frozen_string_literal: true

class SessionsController < ApplicationController
  layout "authentication"
  allow_unauthenticated_access only: %i[new create]
  skip_store_context only: :destroy

  def new
  end

  def create
    username = params.require(:username).to_s.strip.downcase
    user = User.find_by(username: username)

    if user&.authenticate(params.require(:password))
      if !user.active? || user.locked?
        redirect_to new_session_path, alert: "Your account cannot sign in."
        return
      end

      user.update!(failed_login_attempts: 0, last_login_at: Time.current)
      start_new_session_for(user)

      memberships = effective_memberships_for(user)
      if memberships.empty?
        redirect_to no_store_access_path
      elsif session[:store_id].blank? && memberships.many?
        redirect_to new_store_selection_path
      else
        redirect_to after_authentication_url
      end
    else
      user&.increment!(:failed_login_attempts)
      redirect_to new_session_path, alert: "Invalid username or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_path
  end
end
