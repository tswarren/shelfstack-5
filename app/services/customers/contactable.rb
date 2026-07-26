# frozen_string_literal: true

module Customers
  # Preferred-contact contactability uses primary fields only (ADR-0017).
  class Contactable < ApplicationService
    def initialize(customer:)
      @customer = customer
    end

    def call
      return false if @customer.nil?

      case @customer.preferred_contact_method
      when "phone" then @customer.primary_phone.present?
      when "email" then @customer.primary_email.present?
      else false
      end
    end
  end
end
