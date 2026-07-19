# frozen_string_literal: true

class StoreSelectionsController < ApplicationController
  layout "authentication"
  skip_store_context
  before_action :block_if_open_transaction

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

  private

  def block_if_open_transaction
    open_transaction = Pos::CurrentOpenTransaction.for(user: Current.user, store_id: session[:store_id])
    return if open_transaction.blank?

    redirect_to pos_transaction_path(open_transaction),
      alert: "Complete, suspend, or cancel the open transaction before switching stores."
  end
end
