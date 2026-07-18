# frozen_string_literal: true

module Catalog
  class UpdateProductWithStandardVariant < ApplicationService
    def initialize(product:, variant:, product_attrs:, variant_attrs:, actor:, store:)
      @product = product
      @variant = variant
      @product_attrs = product_attrs.to_h.stringify_keys
      @variant_attrs = variant_attrs.to_h.stringify_keys
      @actor = actor
      @store = store
    end

    attr_reader :product, :variant

    def call
      return false if @product_attrs.key?("identifier")
      return false if @variant_attrs.key?("sku")

      ActiveRecord::Base.transaction do
        unless UpdateProduct.call(
          product: @product,
          attributes: @product_attrs,
          actor: @actor,
          store: @store
        )
          raise ActiveRecord::Rollback
        end

        if @variant.present? && @variant_attrs.present?
          unless UpdateVariant.call(
            variant: @variant,
            attributes: @variant_attrs,
            actor: @actor,
            store: @store
          )
            raise ActiveRecord::Rollback
          end
        end
      end

      @product.errors.empty? && (@variant.nil? || @variant.errors.empty?)
    end
  end
end
