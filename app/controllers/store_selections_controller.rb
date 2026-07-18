# frozen_string_literal: true

class StoreSelectionsController < ApplicationController
  skip_store_context

  def new
    @memberships = effective_memberships_for(Current.user)
    redirect_to root_path and return if @memberships.one?
    redirect_to no_store_access_path and return if @memberships.empty?
  end

  def create
    membership = effective_membership_for(Current.user, params.require(:store_id))
    unless membership
      redirect_to new_store_selection_path, alert: "Select a store you can access."
      return
    end

    session[:store_id] = membership.store_id
    set_current_from_membership(Current.user, membership)
    redirect_to root_path
  end
end
