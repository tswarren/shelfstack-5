# frozen_string_literal: true

class CustomersController < ApplicationController
  # Create/edit/deactivate require view so lifecycle actions cannot bypass record access.
  before_action -> { require_permission!("customers.customer.view") },
                only: %i[index show new create edit update deactivate]
  before_action -> { require_permission!("customers.customer.create") }, only: %i[new create]
  before_action -> { require_permission!("customers.customer.edit") }, only: %i[edit update]
  before_action -> { require_permission!("customers.customer.deactivate") }, only: %i[deactivate]
  before_action :set_customer, only: %i[show edit update deactivate]

  def index
    @query = params[:q].to_s.strip
    if @query.present?
      result = Customers::Search.call(
        organization: Current.organization,
        query: @query,
        default_phone_country: Current.store&.country_code
      )
      @customers = result.customers
      @inactive_direct_match = result.inactive_direct_match
    else
      @pagy, @customers = pagy(:offset, Current.organization.customers.active.order(:last_name, :first_name, :organization_name), limit: pagy_limit)
      @inactive_direct_match = nil
    end
  end

  def show
  end

  def new
    @customer = Current.organization.customers.new(
      customer_type: "individual",
      preferred_contact_method: "none",
      country_code: Current.store&.country_code,
      region: Current.store&.region,
      active: true
    )
    @possible_duplicates = []
  end

  def create
    result = Customers::Create.call(
      organization: Current.organization,
      actor: Current.user,
      store: Current.store,
      attributes: customer_create_params.to_h,
      create_anyway: ActiveModel::Type::Boolean.new.cast(params[:create_anyway]),
      default_phone_country: Current.store&.country_code
    )

    if result.success?
      redirect_to customer_path(result.customer), notice: "Customer created."
    elsif result.error == "possible_duplicates"
      @customer = result.customer
      @possible_duplicates = result.possible_duplicates
      flash.now[:alert] = "Possible duplicate customer. Open an existing customer or create a new customer anyway."
      render :new, status: :unprocessable_entity
    else
      @customer = result.customer || Current.organization.customers.new(customer_create_params)
      @possible_duplicates = []
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @possible_duplicates = []
  end

  def update
    result = Customers::Update.call(
      customer: @customer,
      actor: Current.user,
      store: Current.store,
      attributes: customer_update_params.to_h,
      default_phone_country: Current.store&.country_code
    )

    if result.success?
      redirect_to customer_path(@customer), notice: "Customer updated."
    else
      @customer = result.customer
      @possible_duplicates = []
      flash.now[:alert] = result.error
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    result = Customers::Deactivate.call(
      customer: @customer,
      actor: Current.user,
      store: Current.store
    )

    if result.success?
      redirect_to customers_path, notice: "Customer deactivated."
    else
      redirect_to customer_path(@customer), alert: result.error
    end
  end

  private

  def set_customer
    @customer = Current.organization.customers.find(params[:id])
  end

  def customer_create_params
    params.require(:customer).permit(
      :customer_type, :organization_name, :first_name, :last_name,
      :address_line_1, :address_line_2, :city, :region, :postal_code, :country_code,
      :primary_phone, :alternate_phone, :primary_email, :alternate_email,
      :preferred_contact_method, :notes
    )
  end

  def customer_update_params
    params.require(:customer).permit(
      :organization_name, :first_name, :last_name,
      :address_line_1, :address_line_2, :city, :region, :postal_code, :country_code,
      :primary_phone, :alternate_phone, :primary_email, :alternate_email,
      :preferred_contact_method, :notes
    )
  end
end
