# frozen_string_literal: true

require "ostruct"

# Product import surfaces (Gate 8c):
# 1. Create from ISBN — PreviewProductImport → CreateFromEnrichment
# 2. Thin product-from-demand path — ImportProductMetadata (structured attrs)
#
# Lookup ≠ apply: preview requires catalog.lookup_external; accept requires
# catalog.create_from_enrichment and catalog.product.create.
class ProductImportsController < ApplicationController
  before_action :require_import_entry!, only: :new
  before_action -> { require_permission!("catalog.lookup_external") }, only: :preview
  before_action :require_create_from_enrichment!, only: :accept
  before_action -> { require_permission!("catalog.product.create") }, only: :create

  PROVIDERS = [
    [ "ISBNdb", "isbndb" ],
    [ "Google Books", "google_books" ]
  ].freeze

  def new
    @attrs = {}
    @return_to = params[:return_to]
    @identifier = params[:identifier]
    @provider = params[:provider].presence || "isbndb"
  end

  def preview
    @return_to = params[:return_to]
    @identifier = params[:identifier].to_s.strip
    @provider = params[:provider].presence || "isbndb"

    result = Catalog::PreviewProductImport.call(
      actor: Current.user,
      store: Current.store,
      organization: Current.organization,
      identifier: @identifier,
      provider: @provider
    )

    case result.status
    when :existing
      product = result.product || result.products.first
      redirect_to product_path(product),
                  notice: "A product with this identifier already exists. Enrichment of existing products is available in a later gate."
    when :failure
      @attrs = {}
      flash.now[:alert] = result.message.presence || "External lookup failed (#{result.code})."
      render_html :new, status: :unprocessable_entity
    else
      @preview = result
      @product_formats = Current.organization.product_formats.where(active: true).order(:name)
      # Full HTML page — Turbo form posts negotiate as turbo_stream; a 200 with
      # turbo-stream Content-Type and no <turbo-stream> tags leaves the UI unchanged.
      render_html :preview
    end
  rescue Catalog::PreviewProductImport::Error, Catalog::LookupExternalMetadata::Error => error
    @attrs = {}
    flash.now[:alert] = error.message
    render_html :new, status: :forbidden
  end

  def accept
    @return_to = params[:return_to]
    @identifier = params[:identifier].to_s.strip
    @provider = params[:provider].to_s
    @preview_params = accept_params

    result = Catalog::CreateFromEnrichment.call(
      organization: Current.organization,
      actor: Current.user,
      store: Current.store,
      identifier: @identifier,
      provider: @provider,
      provider_record_id: params[:provider_record_id],
      retrieved_at: parse_retrieved_at(params[:retrieved_at]),
      product_attrs: product_attrs_from_accept,
      variant_attrs: variant_attrs_from_accept,
      creator_resolutions: creator_resolutions_from_accept,
      accepted_warnings: accepted_warnings_from_params
    )

    if result.success?
      redirect_to product_path(result.product), notice: "Product created from external metadata."
    elsif result.status == :existing && result.product
      redirect_to product_path(result.product), notice: "A product with this identifier already exists."
    else
      rebuild_preview_for_rerender
      @error = result.message
      @product_formats = Current.organization.product_formats.where(active: true).order(:name)
      render_html :preview, status: :unprocessable_entity
    end
  rescue Catalog::CreateFromEnrichment::Error => error
    rebuild_preview_for_rerender
    @error = error.message
    @product_formats = Current.organization.product_formats.where(active: true).order(:name)
    render_html :preview, status: :forbidden
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
      @identifier = params[:identifier]
      @provider = params[:provider].presence || "isbndb"
      render_html :new, status: :unprocessable_entity
    else
      @attrs = attrs
      @error = result.error
      @identifier = params[:identifier]
      @provider = params[:provider].presence || "isbndb"
      render_html :new, status: :unprocessable_entity
    end
  end

  private

  # Force text/html so Turbo Drive replaces the page after a form POST.
  def render_html(template, status: :ok)
    render template, formats: [ :html ], status: status
  end

  def require_import_entry!
    return if Current.user&.can?("catalog.lookup_external", store: Current.store)
    return if Current.user&.can?("catalog.product.create", store: Current.store)

    require_permission!("catalog.lookup_external")
  end

  def require_create_from_enrichment!
    require_permission!("catalog.create_from_enrichment")
    return if performed?

    require_permission!("catalog.product.create")
  end

  def return_path(product)
    if @return_to.present?
      uri = URI.parse(@return_to)
      query = Rack::Utils.parse_nested_query(uri.query)
      query["product_id"] = product.id
      "#{uri.path}?#{query.to_query}"
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

  def accept_params
    params.permit(
      :identifier, :provider, :provider_record_id, :retrieved_at, :return_to,
      :name, :subtitle, :description, :product_type, :product_format_id,
      :publisher_or_manufacturer_name, :imprint_or_brand_name,
      :publication_date, :publication_date_precision, :language_code, :edition_statement,
      :list_price_cents, :list_price_currency_code,
      :inventory_tracking_mode,
      accepted_warnings: [ :code, :message ],
      creators: [ :action, :creator_id, :display_name, :role, :credited_as ]
    )
  end

  def product_attrs_from_accept
    p = accept_params
    {
      name: p[:name],
      subtitle: p[:subtitle],
      description: p[:description],
      product_type: p[:product_type].presence || "book",
      product_format_id: p[:product_format_id],
      publisher_or_manufacturer_name: p[:publisher_or_manufacturer_name],
      imprint_or_brand_name: p[:imprint_or_brand_name],
      publication_date: p[:publication_date],
      publication_date_precision: p[:publication_date_precision],
      language_code: p[:language_code],
      edition_statement: p[:edition_statement],
      list_price_cents: p[:list_price_cents],
      list_price_currency_code: p[:list_price_currency_code],
      status: "active",
      sellable: false
    }
  end

  def variant_attrs_from_accept
    {
      name: "Standard",
      inventory_tracking_mode: accept_params[:inventory_tracking_mode].presence || "quantity",
      regular_price_cents: nil,
      status: "active",
      sellable: false,
      purchasable: true
    }
  end

  def creator_resolutions_from_accept
    rows = params[:creators]
    return [] if rows.blank?

    enumerable_param_rows(rows).map do |row|
      hash = row.respond_to?(:permit) ? row.permit(:action, :creator_id, :display_name, :role, :credited_as).to_h : row.to_h
      hash.symbolize_keys
    end
  end

  def accepted_warnings_from_params
    rows = params[:accepted_warnings]
    return [] if rows.blank?

    enumerable_param_rows(rows).map do |row|
      hash = row.respond_to?(:permit) ? row.permit(:code, :message).to_h : row.to_h
      hash.stringify_keys
    end
  end

  def enumerable_param_rows(rows)
    case rows
    when ActionController::Parameters, Hash
      rows.to_unsafe_h.values
    else
      Array(rows)
    end
  end

  def parse_retrieved_at(value)
    return Time.current if value.blank?

    Time.zone.parse(value.to_s) || Time.current
  end

  # When accept fails, rebuild a preview-shaped object from submitted params so
  # the operator keeps their selections (Gate 8c validation rerender).
  def rebuild_preview_for_rerender
    p = accept_params
    @preview = OpenStruct.new(
      status: :preview,
      success?: true,
      requested_identifier: @identifier,
      canonical_identifier: @identifier,
      provider: @provider,
      normalized_result: OpenStruct.new(
        provider_record_id: params[:provider_record_id],
        retrieved_at: parse_retrieved_at(params[:retrieved_at]),
        external_subjects: [],
        images: [],
        provider_format: nil
      ),
      proposed_product_attrs: product_attrs_from_accept,
      proposed_variant_attrs: variant_attrs_from_accept,
      format_proposal: OpenStruct.new(
        product_format_id: p[:product_format_id],
        product_format_name: nil,
        provider_format: nil,
        warning: nil
      ),
      list_price_proposal: OpenStruct.new(
        amount_cents: p[:list_price_cents].presence&.to_i,
        currency_code: p[:list_price_currency_code],
        persistable?: p[:list_price_cents].present?,
        assumed_organization_currency?: false,
        display_only?: true
      ),
      creator_suggestions: rebuild_creator_suggestions,
      eligibility_fields: [],
      sale_eligibility_blockers: [],
      warnings: accepted_warnings_from_params,
      unresolved_fields: []
    )
  end

  def rebuild_creator_suggestions
    creator_resolutions_from_accept.map.with_index do |resolution, index|
      OpenStruct.new(
        display_name: resolution[:display_name],
        role: resolution[:role],
        credited_as: resolution[:credited_as],
        position: index,
        resolution: resolution[:action].to_s == "create" ? :propose_create : :suggest_existing,
        matched_creator_id: resolution[:creator_id],
        candidate_creator_ids: Array(resolution[:creator_id])
      )
    end
  end
end
