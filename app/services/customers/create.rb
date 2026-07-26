# frozen_string_literal: true

module Customers
  # Creates a Customer with namespace-22 identity.
  # Duplicate detection runs before insert unless create_anyway is true.
  class Create < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:customer, :success?, :error, :possible_duplicates)

    ATTRIBUTE_KEYS = %w[
      customer_type organization_name first_name last_name
      address_line_1 address_line_2 city region postal_code country_code
      primary_phone alternate_phone primary_email alternate_email
      preferred_contact_method notes
    ].freeze

    def initialize(organization:, actor:, attributes:, store: nil, create_anyway: false, default_phone_country: nil)
      @organization = organization
      @actor = actor
      @attributes = attributes.to_h.stringify_keys.slice(*ATTRIBUTE_KEYS)
      @store = store
      @create_anyway = create_anyway
      @default_phone_country = default_phone_country.presence || store&.country_code
    end

    def call
      attrs = normalize_contact_attributes(@attributes)

      unless @create_anyway
        dupes = FindPossibleDuplicates.call(
          organization: @organization,
          attributes: attrs
        ).customers
        if dupes.any?
          draft = build_unsaved(attrs)
          return Result.new(
            customer: draft, success?: false, error: "possible_duplicates",
            possible_duplicates: dupes
          )
        end
      end

      customer = nil
      ActiveRecord::Base.transaction do
        number = Identifiers::Generate.call(
          namespace: "22",
          occupied: ->(candidate) { Customer.exists?(customer_number: candidate) }
        )
        customer = @organization.customers.create!(attrs.merge(
          customer_number: number,
          active: true
        ))

        if @store.present? && @actor.present?
          Administration::RecordAuditEvent.call(
            actor: @actor,
            organization: @organization,
            store: @store,
            action: "customers.customer.created",
            subject: customer,
            metadata: { "customer_number" => customer.customer_number }
          )
        end
      end

      Result.new(customer: customer, success?: true, error: nil, possible_duplicates: [])
    rescue NormalizePhone::Error => e
      draft = build_unsaved(@attributes)
      draft.errors.add(:base, e.message)
      Result.new(customer: draft, success?: false, error: e.message, possible_duplicates: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(customer: e.record, success?: false, error: e.record.errors.full_messages.to_sentence, possible_duplicates: [])
    rescue Identifiers::Generate::SequenceOverflowError => e
      Result.new(customer: build_unsaved(attrs), success?: false, error: e.message, possible_duplicates: [])
    end

    private

    def build_unsaved(attrs)
      @organization.customers.new(attrs.merge(active: true))
    end

    def normalize_contact_attributes(attrs)
      country = attrs["country_code"].to_s.strip.upcase.presence
      out = attrs.dup
      out["country_code"] = country
      out["preferred_contact_method"] = (attrs["preferred_contact_method"].presence || "none")
      out["primary_email"] = NormalizeEmail.call(attrs["primary_email"])
      out["alternate_email"] = NormalizeEmail.call(attrs["alternate_email"])
      out["primary_phone"] = normalize_phone_field(attrs["primary_phone"], country)
      out["alternate_phone"] = normalize_phone_field(attrs["alternate_phone"], country)
      out
    end

    def normalize_phone_field(raw, customer_country)
      NormalizePhone.call(
        raw,
        customer_country: customer_country,
        default_country: @default_phone_country
      )
    end
  end
end
