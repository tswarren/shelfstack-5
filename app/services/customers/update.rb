# frozen_string_literal: true

module Customers
  class Update < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:customer, :success?, :error)

    # Lifecycle fields (customer_type, active) are intentionally excluded —
    # type is immutable after create; active changes go through Deactivate.
    ATTRIBUTE_KEYS = %w[
      organization_name first_name last_name
      address_line_1 address_line_2 city region postal_code country_code
      primary_phone alternate_phone primary_email alternate_email
      preferred_contact_method notes
    ].freeze

    def initialize(customer:, actor:, attributes:, store: nil, default_phone_country: nil)
      @customer = customer
      @actor = actor
      @attributes = attributes.to_h.stringify_keys.slice(*ATTRIBUTE_KEYS)
      @store = store
      @default_phone_country = default_phone_country.presence || store&.country_code
    end

    def call
      attrs = normalize_contact_attributes(@attributes)

      ActiveRecord::Base.transaction do
        @customer.update!(attrs)

        if @store.present? && @actor.present?
          Administration::RecordAuditEvent.call(
            actor: @actor,
            organization: @customer.organization,
            store: @store,
            action: "customers.customer.updated",
            subject: @customer,
            metadata: { "customer_number" => @customer.customer_number }
          )
        end
      end

      Result.new(customer: @customer, success?: true, error: nil)
    rescue PhoneFieldError => e
      apply_attempted_attributes!(@attributes)
      @customer.errors.add(e.attribute, e.message)
      Result.new(customer: @customer, success?: false, error: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(customer: e.record, success?: false, error: e.record.errors.full_messages.to_sentence)
    end

    private

    PhoneFieldError = Class.new(StandardError) do
      attr_reader :attribute

      def initialize(attribute, message)
        @attribute = attribute
        super(message)
      end
    end

    def normalize_contact_attributes(attrs)
      country = attrs.key?("country_code") ? attrs["country_code"].to_s.strip.upcase.presence : @customer.country_code
      out = attrs.dup
      out["country_code"] = country if attrs.key?("country_code")
      out["primary_email"] = NormalizeEmail.call(attrs["primary_email"]) if attrs.key?("primary_email")
      out["alternate_email"] = NormalizeEmail.call(attrs["alternate_email"]) if attrs.key?("alternate_email")
      normalize_phone_key!(out, attrs, "primary_phone", country)
      normalize_phone_key!(out, attrs, "alternate_phone", country)
      out
    end

    def normalize_phone_key!(out, attrs, key, country)
      return unless attrs.key?(key)

      out[key] = NormalizePhone.call(
        attrs[key],
        customer_country: country,
        default_country: @default_phone_country
      )
    rescue NormalizePhone::Error => e
      raise PhoneFieldError.new(key.to_sym, e.message)
    end

    # Keep submitted values on the instance so edit re-renders preserve form state.
    def apply_attempted_attributes!(attrs)
      @customer.assign_attributes(attrs.slice(*ATTRIBUTE_KEYS))
    end
  end
end
