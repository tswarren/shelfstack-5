# frozen_string_literal: true

class StoresController < ApplicationController
  before_action -> { require_permission!("administration.store.view") }, only: %i[index show]
  before_action -> { require_permission!("administration.store.manage") }, only: %i[new create edit update]
  before_action :set_store, only: %i[show edit update]

  def index
    @stores = Current.organization.stores.order(:code)
  end

  def show
  end

  def new
    @store = Current.organization.stores.new(
      timezone: Current.organization.default_timezone,
      currency_code: Current.organization.default_currency_code
    )
  end

  def create
    @store = Current.organization.stores.new(store_params)
    if Administration::CreateStore.call(
      store: @store,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @store, notice: "Store created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if Administration::UpdateStore.call(
      store: @store,
      attributes: store_params.to_h,
      actor: Current.user,
      organization: Current.organization
    )
      redirect_to @store, notice: "Store updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_store
    @store = Current.organization.stores.find(params[:id])
  end

  def store_params
    params.require(:store).permit(
      :code, :store_number, :name, :legal_name, :address_line_1, :address_line_2,
      :city, :region, :postal_code, :country_code, :phone, :email, :san_number,
      :timezone, :currency_code, :receipt_header, :receipt_footer, :active
    )
  end
end
