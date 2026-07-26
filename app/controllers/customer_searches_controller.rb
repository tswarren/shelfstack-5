# frozen_string_literal: true

# JSON/HTML fragment search for Customer pickers (Product Requests, POS).
class CustomerSearchesController < ApplicationController
  before_action -> { require_permission!("customers.customer.view") }

  def index
    result = Customers::Search.call(
      organization: Current.organization,
      query: params[:q].to_s,
      default_phone_country: Current.store&.country_code
    )
    @customers = result.customers
    @inactive_direct_match = result.inactive_direct_match

    respond_to do |format|
      format.html { render layout: false }
      format.json do
        render json: {
          customers: @customers.map { |c| customer_json(c) },
          inactive_direct_match: @inactive_direct_match && customer_json(@inactive_direct_match)
        }
      end
    end
  end

  private

  def customer_json(customer)
    {
      id: customer.id,
      display_name: customer.display_name,
      customer_number: customer.customer_number,
      customer_type: customer.customer_type,
      primary_phone: customer.primary_phone,
      primary_email: customer.primary_email,
      preferred_contact_method: customer.preferred_contact_method,
      contactable: customer.contactable?,
      active: customer.active?
    }
  end
end
