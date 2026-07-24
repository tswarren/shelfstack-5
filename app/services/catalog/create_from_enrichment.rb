# frozen_string_literal: true

module Catalog
  # Persist a Product + standard Variant + Creators + catalog_enrichment_events
  # row from an accepted create-from-ISBN preview (Gate 8c).
  #
  # Requires both `catalog.create_from_enrichment` and `catalog.product.create`.
  # The provider call must already be complete: pass accepted fields / provider
  # provenance in. Creates nothing on authorization failure, local duplicate,
  # or any in-transaction error (full rollback).
  class CreateFromEnrichment < ApplicationService
    Error = Class.new(StandardError)

    CreateResult = Data.define(
      :success?, :status, :code, :message,
      :product, :variant, :enrichment_event, :errors
    )

    PRODUCT_ATTR_KEYS = %i[
      name subtitle description product_type product_format_id
      merchandise_class_id default_department_id default_tax_category_id
      status sellable list_price_cents
      publisher_or_manufacturer_name imprint_or_brand_name
      publication_date publication_date_precision language_code edition_statement
    ].freeze

    VARIANT_ATTR_KEYS = %i[
      name inventory_tracking_mode regular_price_cents status sellable purchasable
      department_id tax_category_id merchandise_class_id
    ].freeze

    def initialize(
      organization:, actor:, store:,
      identifier:, provider:, provider_record_id:, retrieved_at:,
      product_attrs:, variant_attrs:,
      creator_resolutions: [],
      accepted_warnings: []
    )
      @organization = organization
      @actor = actor
      @store = store
      @identifier = identifier
      @provider = provider.to_s
      @provider_record_id = provider_record_id
      @retrieved_at = retrieved_at
      @product_attrs = product_attrs.to_h.symbolize_keys
      @variant_attrs = variant_attrs.to_h.symbolize_keys
      @creator_resolutions = Array(creator_resolutions).map { |row| row.to_h.symbolize_keys }
      @accepted_warnings = Array(accepted_warnings)
      @errors = []
    end

    def call
      authorize!

      existing = Catalog::FindExistingProduct.call(organization: @organization, identifier: @identifier)
      return existing_result(existing) if existing.found?

      product = nil
      variant = nil
      event = nil

      ActiveRecord::Base.transaction do
        existing_inside = Catalog::FindExistingProduct.call(organization: @organization, identifier: @identifier)
        if existing_inside.found?
          @errors << "A product with this identifier already exists."
          raise ActiveRecord::Rollback
        end

        creator_assignments = resolve_creators!
        enforce_operational_safety!

        create = Catalog::CreateProduct.new(
          organization: @organization,
          actor: @actor,
          store: @store,
          identifier: existing.canonical_identifier.presence || @identifier,
          product_attrs: sanitized_product_attrs,
          variant_attrs: sanitized_variant_attrs,
          creator_assignments: creator_assignments
        )

        unless create.call
          @errors = create.product&.errors&.full_messages.presence || [ "could not create product from enrichment" ]
          raise ActiveRecord::Rollback
        end

        product = create.product
        variant = create.variant
        event = write_enrichment_event!(product)
      end

      if product&.persisted? && event&.persisted?
        CreateResult.new(
          success?: true, status: :created, code: nil, message: nil,
          product: product, variant: variant, enrichment_event: event, errors: []
        )
      else
        # Concurrent create may have won; redirect callers to the existing row.
        raced = Catalog::FindExistingProduct.call(organization: @organization, identifier: @identifier)
        return existing_result(raced) if raced.found?

        CreateResult.new(
          success?: false, status: :failure, code: :create_failed,
          message: @errors.to_sentence.presence || "could not create product from enrichment",
          product: nil, variant: nil, enrichment_event: nil, errors: @errors
        )
      end
    rescue ActiveRecord::RecordInvalid => error
      CreateResult.new(
        success?: false, status: :failure, code: :create_failed,
        message: error.record.errors.full_messages.to_sentence,
        product: nil, variant: nil, enrichment_event: nil,
        errors: error.record.errors.full_messages
      )
    end

    private

    def authorize!
      unless permission_allowed?("catalog.create_from_enrichment")
        raise Error, "not permitted to create from enrichment"
      end
      unless permission_allowed?("catalog.product.create")
        raise Error, "not permitted to create products"
      end
    end

    def permission_allowed?(key)
      Authorization::EvaluatePermission.call(
        user: @actor, store: @store, permission_key: key
      ) == :allow
    end

    def existing_result(existing)
      CreateResult.new(
        success?: false,
        status: :existing,
        code: :existing_product,
        message: "A product with this identifier already exists.",
        product: existing.product || existing.products.first,
        variant: nil,
        enrichment_event: nil,
        errors: [ "A product with this identifier already exists." ]
      )
    end

    def enforce_operational_safety!
      # OD-P8-01: never become sellable or copy list price into regular price
      # from enrichment. Operator may pass sellable only if they also supply
      # eligibility — still force false here for create-from-enrichment.
      @product_attrs[:sellable] = false
      @variant_attrs[:sellable] = false
      @variant_attrs[:regular_price_cents] = nil if enrichment_would_copy_list_price?
      @variant_attrs.delete(:regular_price_cents) if @variant_attrs[:regular_price_cents].blank?
      @product_attrs[:list_price_cents] = persistable_list_price_cents
    end

    def enrichment_would_copy_list_price?
      list = @product_attrs[:list_price_cents]
      regular = @variant_attrs[:regular_price_cents]
      list.present? && regular.present? && list.to_i == regular.to_i
    end

    def persistable_list_price_cents
      cents = @product_attrs[:list_price_cents]
      return nil if cents.blank?

      currency = @product_attrs[:list_price_currency_code].to_s.strip.upcase.presence
      org_currency = @organization.default_currency_code.to_s.upcase
      return cents.to_i if currency.blank? || currency == org_currency

      nil
    end

    def sanitized_product_attrs
      @product_attrs.slice(*PRODUCT_ATTR_KEYS).merge(sellable: false)
    end

    def sanitized_variant_attrs
      attrs = @variant_attrs.slice(*VARIANT_ATTR_KEYS).merge(sellable: false)
      attrs[:inventory_tracking_mode] ||= "quantity"
      attrs[:name] ||= "Standard"
      attrs[:status] ||= "active"
      attrs[:purchasable] = true unless attrs.key?(:purchasable)
      attrs.delete(:regular_price_cents) if attrs[:regular_price_cents].blank?
      attrs
    end

    def resolve_creators!
      @creator_resolutions.map do |resolution|
        action = resolution[:action].to_s
        role = resolution[:role].presence || "contributor"
        credited_as = resolution[:credited_as]

        case action
        when "use_existing", "existing"
          creator_id = resolution[:creator_id]
          if creator_id.blank?
            @errors << "Creator is required for an existing-creator resolution."
            raise ActiveRecord::Rollback
          end

          creator = @organization.creators.find_by(id: creator_id)
          unless creator
            @errors << "Selected creator is not available in this organization."
            raise ActiveRecord::Rollback
          end
          { creator_id: creator.id, role: role, credited_as: credited_as }
        when "create"
          display_name = resolution[:display_name].to_s.strip
          if display_name.blank?
            @errors << "Creator display name is required when creating a creator."
            raise ActiveRecord::Rollback
          end
          creator = @organization.creators.create!(
            display_name: display_name,
            sort_name: resolution[:sort_name].presence || display_name,
            active: true
          )
          { creator_id: creator.id, role: role, credited_as: credited_as }
        else
          @errors << "Unknown creator resolution action: #{action.inspect}"
          raise ActiveRecord::Rollback
        end
      end
    end

    def write_enrichment_event!(product)
      CatalogEnrichmentEvent.create!(
        product: product,
        organization: @organization,
        actor_user: @actor,
        provider: @provider,
        provider_record_id: @provider_record_id,
        requested_identifier: @identifier.to_s,
        canonical_identifier: product.identifier,
        action: "create",
        retrieved_at: @retrieved_at || Time.current,
        applied_fields: applied_fields_for(product),
        accepted_warnings: normalized_accepted_warnings
      )
    end

    def applied_fields_for(product)
      fields = {}
      PRODUCT_ATTR_KEYS.each do |key|
        next if key == :sellable

        value = product.public_send(key)
        fields[key.to_s] = serialize_applied_value(value) unless value.nil?
      end
      fields["creator_ids"] = product.product_creators.order(:position, :id).pluck(:creator_id)
      fields["variant"] = {
        "inventory_tracking_mode" => product.product_variants.first&.inventory_tracking_mode,
        "sellable" => false,
        "regular_price_cents" => product.product_variants.first&.regular_price_cents
      }
      fields
    end

    def serialize_applied_value(value)
      case value
      when Date, Time, ActiveSupport::TimeWithZone then value.iso8601
      else value
      end
    end

    def normalized_accepted_warnings
      @accepted_warnings.map do |warning|
        hash = warning.respond_to?(:to_h) ? warning.to_h : warning
        hash = hash.stringify_keys
        hash.slice("code", "message", "details")
      end
    end
  end
end
