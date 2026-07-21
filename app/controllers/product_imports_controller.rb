# frozen_string_literal: true

# Thin product-from-demand path (ordering-and-acquisition-planning.md §3.1):
# search the local catalog, then quick-create a Product from a structured
# attributes hash, and return to the originating Product Request form with
# the new Product selected. Not a live external-catalog integration.
class ProductImportsController < ApplicationController
  before_action -> { require_permission!("catalog.product.create") }

  def new
    @attrs = {}
    @return_to = params[:return_to]
  end

  def create
    @return_to = params[:return_to]
    attrs = import_params

    result = Catalog::ImportProductMetadata.call(
      organization: Current.organization,
      actor: Current.user,
      store: Current.store,
      attrs: attrs,
      accept_duplicate_review: ActiveModel::Type::Boolean.new.cast(params[:accept_duplicate_review]),
      accept_identifier_warning: ActiveModel::Type::Boolean.new.cast(params[:accept_identifier_warning])
    )

    if result.success?
      redirect_to return_path(result.product), notice: "Product imported."
    elsif result.duplicate_candidates.present?
      @attrs = attrs
      @duplicate_candidates = result.duplicate_candidates
      @warnings = result.warnings
      render :new, status: :unprocessable_entity
    else
      @attrs = attrs
      @error = result.error
      render :new, status: :unprocessable_entity
    end
  end

  private

  def return_path(product)
    if @return_to.present?
      uri = URI.parse(@return_to)
      params = Rack::Utils.parse_nested_query(uri.query)
      params["product_id"] = product.id
      "#{uri.path}?#{params.to_query}"
    else
      new_product_request_path(product_id: product.id)
    end
  end

  def import_params
    attrs = params.require(:product).permit(
      :identifier, :name, :subtitle, :description, :product_type, :product_format_id,
      :merchandise_class_id, :default_department_id, :default_tax_category_id,
      :list_price_cents, :sku, :regular_price_cents, :inventory_tracking_mode, :purchasable
    ).to_h.symbolize_keys
    attrs[:status] = "active"
    attrs
  end
end
