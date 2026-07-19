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
    if (open_transaction = open_transaction_blocking_signout)
      redirect_to pos_transaction_path(open_transaction),
        alert: "Complete, suspend, or cancel the open transaction before signing out."
      return
    end

    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_path
  end

  # Sign-out is blocked while the cashier still controls an open transaction in
  # the active store (phase-04f-ux-baseline.md POS store-switch and sign-out).
  # Store context is skipped on destroy, so the store is resolved from session.
  def open_transaction_blocking_signout
    return nil if Current.user.blank?

    store_id = session[:store_id]
    return nil if store_id.blank?

    store = Store.find_by(id: store_id)
    return nil if store.blank?

    open_session = store.pos_sessions.open_sessions.find_by(cashier_user: Current.user)
    return nil if open_session.blank?

    PosTransaction.open_transactions.find_by(active_pos_session: open_session)
  end
end
