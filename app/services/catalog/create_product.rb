# frozen_string_literal: true

module Catalog
  class CreateProduct < ApplicationService
    PRODUCT_TRACKED_ATTRIBUTES = %w[
      identifier name subtitle description product_type product_format_id merchandise_class_id
      default_department_id default_tax_category_id status sellable list_price_cents
    ].freeze

    VARIANT_TRACKED_ATTRIBUTES = %w[
      sku name inventory_tracking_mode regular_price_cents status sellable purchasable
      department_id tax_category_id merchandise_class_id
    ].freeze

    PRODUCT_IDENTIFIER_TYPES = %i[isbn13 ean13 upc_a generated_29 other].freeze
    MAX_COLLISION_RETRIES = 5

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
      build_unsaved_shells!

      attempts = 0
      begin
        attempts += 1
        ActiveRecord::Base.transaction do
          normalized = resolve_identifier_inside_transaction!
          unless identifier_acceptable?(normalized)
            add_identifier_rejection_errors!(normalized)
            raise ActiveRecord::Rollback
          end

          create_product!(normalized)
          create_variant!
          apply_final_states!
          audit!
        end

        return false if @product&.errors&.any?
        return false if @product.nil? || @product.new_record?

        true
      rescue ActiveRecord::RecordNotUnique
        if @generated_identifier && attempts < MAX_COLLISION_RETRIES
          @product = nil
          @variant = nil
          @generated_identifier = false
          build_unsaved_shells!
          retry
        end

        @product&.errors&.add(:identifier, "has already been taken")
        false
      rescue ActiveRecord::RecordInvalid
        copy_variant_errors_to_product!
        false
      end
    end

    private

    def build_unsaved_shells!
      @product = @organization.products.build(@product_attrs.except(:status, :sellable))
      @product.status = @product_attrs.fetch(:status, "active")
      @product.sellable = false
      @variant = ProductVariant.new(
        @variant_attrs.merge(name: @variant_attrs.fetch(:name, "Standard"))
      )
    end

    def resolve_identifier_inside_transaction!
      if @identifier.blank?
        generated = Identifiers::Generate.call(namespace: "29")
        @generated_identifier = true
        return Identifiers::Normalize.call(generated)
      end

      Identifiers::Normalize.call(@identifier)
    end

    def identifier_acceptable?(normalized)
      unless PRODUCT_IDENTIFIER_TYPES.include?(normalized.type)
        return false
      end

      case normalized.validation_status
      when :valid, :not_applicable
        true
      when :warning
        @accept_identifier_warning
      else
        false
      end
    end

    def add_identifier_rejection_errors!(normalized)
      detail = normalized.warnings.join("; ").presence || "identifier is not acceptable"
      display = normalized.canonical.presence || normalized.normalized.presence || @identifier.to_s

      if %i[generated_21 generated_27 generated_28].include?(normalized.type)
        @product.errors.add(
          :identifier,
          "#{display}: namespace #{normalized.type.to_s.delete_prefix("generated_")} is not valid for products"
        )
        return
      end

      case normalized.validation_status
      when :warning
        @product.errors.add(
          :identifier,
          "#{display}: #{detail}. Check “Accept identifier warning” to save anyway."
        )
      when :invalid
        @product.errors.add(:identifier, "#{display}: #{detail}")
      else
        @product.errors.add(:identifier, detail)
      end
    end

    def create_product!(normalized)
      @product.identifier = normalized.canonical
      @product.identifier_generated = @generated_identifier
      @product.identifier_validation_status = normalized.validation_status.to_s
      @product.identifier_warning = normalized.warnings.join("; ").presence
      @product.sellable = false
      @product.save!
    end

    def create_variant!
      @variant.product = @product
      @variant.sku = Identifiers::Generate.call(namespace: "28")
      @variant.name = @variant_attrs.fetch(:name, "Standard")
      @variant.status = "active"
      @variant.sellable = false
      @variant.purchasable = ActiveModel::Type::Boolean.new.cast(
        @variant_attrs.fetch(:purchasable, true)
      )
      @variant.save!
    end

    def apply_final_states!
      product_updates = @product_attrs.slice(:status, :sellable)
      @product.update!(product_updates) if product_updates.any?

      variant_updates = @variant_attrs.slice(:status, :sellable, :purchasable)
      @variant.update!(variant_updates) if variant_updates.any?
    end

    def copy_variant_errors_to_product!
      return if @variant.blank? || @variant.errors.empty?
      return if @product.errors.any?

      @variant.errors.full_messages.each do |message|
        @product.errors.add(:base, "Variant: #{message}")
      end
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
