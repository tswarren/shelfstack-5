# frozen_string_literal: true

module Customers
  class Update < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:customer, :success?, :error)

    ATTRIBUTE_KEYS = Create::ATTRIBUTE_KEYS - %w[customer_type]

    def initialize(customer:, actor:, attributes:, store: nil, default_phone_country: nil)
      @customer = customer
      @actor = actor
      @attributes = attributes.to_h.stringify_keys.slice(*Create::ATTRIBUTE_KEYS)
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
    rescue NormalizePhone::Error => e
      @customer.errors.add(:base, e.message)
      Result.new(customer: @customer, success?: false, error: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(customer: e.record, success?: false, error: e.record.errors.full_messages.to_sentence)
    end

    private

    def normalize_contact_attributes(attrs)
      country = attrs.key?("country_code") ? attrs["country_code"].to_s.strip.upcase.presence : @customer.country_code
      out = attrs.dup
      out["country_code"] = country if attrs.key?("country_code")
      out["primary_email"] = NormalizeEmail.call(attrs["primary_email"]) if attrs.key?("primary_email")
      out["alternate_email"] = NormalizeEmail.call(attrs["alternate_email"]) if attrs.key?("alternate_email")
      if attrs.key?("primary_phone")
        out["primary_phone"] = NormalizePhone.call(
          attrs["primary_phone"],
          customer_country: country,
          default_country: @default_phone_country
        )
      end
      if attrs.key?("alternate_phone")
        out["alternate_phone"] = NormalizePhone.call(
          attrs["alternate_phone"],
          customer_country: country,
          default_country: @default_phone_country
        )
      end
      out
    end
  end
end
