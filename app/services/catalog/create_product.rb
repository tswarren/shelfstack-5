# frozen_string_literal: true

module Catalog
  class CreateProduct < ApplicationService
    PRODUCT_TRACKED_ATTRIBUTES = %w[
      identifier name subtitle description product_type merchandise_class_id
      default_department_id default_tax_category_id status sellable list_price_cents
    ].freeze

    VARIANT_TRACKED_ATTRIBUTES = %w[
      sku name inventory_tracking_mode regular_price_cents status sellable purchasable
      department_id tax_category_id merchandise_class_id
    ].freeze

    def initialize(organization:, actor:, store:, product_attrs:, variant_attrs:,
                   identifier: nil, accept_identifier_warning: false)
      @organization = organization
      @actor = actor
      @store = store
      @product_attrs = product_attrs.to_h.symbolize_keys
      @variant_attrs = variant_attrs.to_h.symbolize_keys
      @identifier = identifier
      @accept_identifier_warning = accept_identifier_warning
      @product = nil
      @variant = nil
      @generated_identifier = false
    end

    attr_reader :product, :variant

    def call
      normalized = resolve_identifier
      return false unless identifier_acceptable?(normalized)

      ActiveRecord::Base.transaction do
        create_product!(normalized)
        create_variant!
        apply_final_states!
        audit!
      end
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      false
    end

    private

    def resolve_identifier
      if @identifier.blank?
        generated = Identifiers::Generate.call(namespace: "29")
        @generated_identifier = true
        return Identifiers::Normalize.call(generated)
      end

      Identifiers::Normalize.call(@identifier)
    end

    def identifier_acceptable?(normalized)
      case normalized.validation_status
      when :valid, :not_applicable
        true
      when :warning
        @accept_identifier_warning
      else
        false
      end
    end

    def create_product!(normalized)
      initial_attrs = @product_attrs.except(:status, :sellable)
      @product = @organization.products.build(initial_attrs)
      @product.identifier = normalized.canonical
      @product.identifier_generated = @generated_identifier
      @product.identifier_validation_status = normalized.validation_status.to_s
      @product.identifier_warning = normalized.warnings.join("; ").presence
      @product.status = @product_attrs.fetch(:status, "active")
      @product.sellable = false
      @product.save!
    end

    def create_variant!
      initial_variant_attrs = @variant_attrs.except(:status, :sellable, :purchasable)
      @variant = @product.product_variants.build(
        initial_variant_attrs.merge(
          sku: Identifiers::Generate.call(namespace: "28"),
          name: @variant_attrs.fetch(:name, "Standard"),
          status: "active",
          sellable: false,
          purchasable: @variant_attrs.fetch(:purchasable, true)
        )
      )
      @variant.save!
    end

    def apply_final_states!
      product_updates = @product_attrs.slice(:status, :sellable)
      @product.update!(product_updates) if product_updates.any?

      variant_updates = @variant_attrs.slice(:status, :sellable, :purchasable)
      @variant.update!(variant_updates) if variant_updates.any?
    end

    def audit!
      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: @organization,
        store: @store,
        action: "catalog.product.created",
        subject: @product,
        metadata: {
          "identifier" => @product.identifier,
          "after" => Administration::ChangeMetadata.snapshot(@product, PRODUCT_TRACKED_ATTRIBUTES)
        }
      )

      Administration::RecordAuditEvent.call(
        actor: @actor,
        organization: @organization,
        store: @store,
        action: "catalog.variant.created",
        subject: @variant,
        metadata: {
          "sku" => @variant.sku,
          "product_id" => @product.id,
          "after" => Administration::ChangeMetadata.snapshot(@variant, VARIANT_TRACKED_ATTRIBUTES)
        }
      )
    end
  end
end
