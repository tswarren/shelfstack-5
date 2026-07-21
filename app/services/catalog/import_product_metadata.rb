# frozen_string_literal: true

module Catalog
  # Thin product-from-demand path (ordering-and-acquisition-planning.md §3.1):
  # search-first, then create from a structured attributes hash. This is not a
  # live external-catalog integration — `attrs` already carries the metadata
  # staff want to save (e.g. hand-entered, or copied from a reference source).
  #
  # Before delegating to Catalog::CreateProduct, checks the local catalog for
  # likely duplicates (exact identifier/SKU match, or a name match) and
  # surfaces them as review candidates instead of silently creating a second
  # record. Pass `accept_duplicate_review: true` once staff have reviewed the
  # candidates and still want to create a new product.
  class ImportProductMetadata < ApplicationService
    ImportResult = Data.define(:product, :variant, :success?, :duplicate_candidates, :warnings, :error)

    def initialize(organization:, actor:, store:, attrs:, accept_duplicate_review: false, accept_identifier_warning: false)
      @organization = organization
      @actor = actor
      @store = store
      @attrs = attrs.to_h.symbolize_keys
      @accept_duplicate_review = ActiveModel::Type::Boolean.new.cast(accept_duplicate_review)
      @accept_identifier_warning = ActiveModel::Type::Boolean.new.cast(accept_identifier_warning)
    end

    def call
      candidates = duplicate_candidates
      if candidates.present? && !@accept_duplicate_review
        return ImportResult.new(
          product: nil, variant: nil, success?: false, duplicate_candidates: candidates,
          warnings: [ "Possible duplicate product(s) found. Review the existing product(s), or resubmit to create a new one anyway." ],
          error: nil
        )
      end

      service = Catalog::CreateProduct.new(
        organization: @organization,
        actor: @actor,
        store: @store,
        product_attrs: @attrs.slice(*Catalog::CreateProduct::PRODUCT_TRACKED_ATTRIBUTES.map(&:to_sym)),
        variant_attrs: @attrs.slice(*(Catalog::CreateProduct::VARIANT_TRACKED_ATTRIBUTES.map(&:to_sym) + [ :purchasable ])),
        identifier: @attrs[:identifier],
        accept_identifier_warning: @accept_identifier_warning
      )

      if service.call
        ImportResult.new(product: service.product, variant: service.variant, success?: true,
                          duplicate_candidates: [], warnings: [], error: nil)
      else
        ImportResult.new(product: service.product, variant: service.variant, success?: false,
                          duplicate_candidates: [], warnings: [],
                          error: service.product&.errors&.full_messages&.to_sentence || "could not import product")
      end
    end

    private

    def duplicate_candidates
      return [] if @attrs[:identifier].blank? && @attrs[:name].blank?

      matches = []

      if @attrs[:identifier].present?
        lookup = Catalog::Lookup.call(organization: @organization, query: @attrs[:identifier])
        matches.concat(lookup.products) unless lookup.empty?
      end

      if @attrs[:name].present?
        matches.concat(
          @organization.products.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@attrs[:name])}%").limit(5)
        )
      end

      matches.uniq(&:id)
    end
  end
end
