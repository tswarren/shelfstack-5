# frozen_string_literal: true

module Catalog
  # Build a create-from-ISBN preview from external metadata (Gate 8c).
  # Requires `catalog.lookup_external`. Performs no DB writes and creates no
  # enrichment events. Persist is Catalog::CreateFromEnrichment.
  class PreviewProductImport < ApplicationService
    Error = Class.new(StandardError)

    DEFAULT_VARIANT_ATTRS = {
      name: "Standard",
      inventory_tracking_mode: "quantity",
      regular_price_cents: nil,
      status: "active",
      sellable: false,
      purchasable: false
    }.freeze

    CreatorSuggestion = Data.define(
      :display_name, :role, :credited_as, :position,
      :resolution, :matched_creator_id, :candidate_creator_ids
    )

    ListPriceProposal = Data.define(
      :amount_cents, :currency_code, :persistable?, :assumed_organization_currency?, :display_only?
    )

    FormatProposal = Data.define(:product_format_id, :product_format_name, :provider_format, :warning)

    EligibilityField = Data.define(:field, :status, :value, :source)

    PreviewResult = Data.define(
      :status, :success?, :code, :message,
      :product, :products, :match_kind,
      :requested_identifier, :canonical_identifier, :provider,
      :normalized_result,
      :proposed_product_attrs, :proposed_variant_attrs,
      :format_proposal, :list_price_proposal, :creator_suggestions,
      :eligibility_fields, :sale_eligibility_blockers,
      :warnings, :unresolved_fields
    )

    def initialize(actor:, store:, organization:, identifier:, provider:, transport: nil, api_key: nil)
      @actor = actor
      @store = store
      @organization = organization
      @identifier = identifier
      @provider = provider
      @transport = transport
      @api_key = api_key
    end

    def call
      raise Error, "not permitted to look up external metadata" unless lookup_authorized?

      existing = Catalog::FindExistingProduct.call(organization: @organization, identifier: @identifier)
      if existing.found?
        return existing_result(existing)
      end

      lookup = Catalog::LookupExternalMetadata.call(
        actor: @actor,
        store: @store,
        identifier: @identifier,
        provider: @provider,
        transport: @transport,
        api_key: @api_key
      )
      return provider_failure_result(lookup, existing) unless lookup.success?

      build_preview(lookup.normalized_result, existing)
    rescue ArgumentError => error
      PreviewResult.new(
        status: :failure,
        success?: false,
        code: :unsupported_provider,
        message: error.message,
        product: nil,
        products: [],
        match_kind: :none,
        requested_identifier: @identifier.to_s,
        canonical_identifier: nil,
        provider: @provider.to_s,
        normalized_result: nil,
        proposed_product_attrs: {},
        proposed_variant_attrs: {},
        format_proposal: nil,
        list_price_proposal: nil,
        creator_suggestions: [],
        eligibility_fields: [],
        sale_eligibility_blockers: [],
        warnings: [],
        unresolved_fields: []
      )
    end

    private

    def lookup_authorized?
      Authorization::EvaluatePermission.call(
        user: @actor, store: @store, permission_key: "catalog.lookup_external"
      ) == :allow
    end

    def existing_result(existing)
      PreviewResult.new(
        status: :existing,
        success?: true,
        code: nil,
        message: nil,
        product: existing.product,
        products: existing.products,
        match_kind: existing.match_kind,
        requested_identifier: @identifier.to_s,
        canonical_identifier: existing.canonical_identifier,
        provider: nil,
        normalized_result: nil,
        proposed_product_attrs: {},
        proposed_variant_attrs: {},
        format_proposal: nil,
        list_price_proposal: nil,
        creator_suggestions: [],
        eligibility_fields: [],
        sale_eligibility_blockers: [],
        warnings: [],
        unresolved_fields: []
      )
    end

    def provider_failure_result(lookup, existing)
      PreviewResult.new(
        status: :failure,
        success?: false,
        code: lookup.code,
        message: lookup.message,
        product: nil,
        products: [],
        match_kind: existing.match_kind,
        requested_identifier: @identifier.to_s,
        canonical_identifier: existing.canonical_identifier,
        provider: @provider.to_s,
        normalized_result: nil,
        proposed_product_attrs: {},
        proposed_variant_attrs: {},
        format_proposal: nil,
        list_price_proposal: nil,
        creator_suggestions: [],
        eligibility_fields: [],
        sale_eligibility_blockers: [],
        warnings: [],
        unresolved_fields: []
      )
    end

    def build_preview(normalized, existing)
      format_proposal = format_proposal_for(normalized)
      list_price = list_price_proposal_for(normalized)
      creators = creator_suggestions_for(normalized)
      product_attrs = proposed_product_attrs(normalized, format_proposal, list_price)
      variant_attrs = DEFAULT_VARIANT_ATTRS.dup
      warnings = Array(normalized.warnings).map { |warning| warning_hash(warning) }
      warnings << warning_hash(format_proposal.warning) if format_proposal.warning
      unresolved = unresolved_fields_for(product_attrs, format_proposal, creators)
      eligibility = eligibility_fields_for(product_attrs, variant_attrs)
      blockers = sale_eligibility_blockers_for(product_attrs, variant_attrs)

      PreviewResult.new(
        status: :preview,
        success?: true,
        code: nil,
        message: nil,
        product: nil,
        products: [],
        match_kind: existing.match_kind,
        requested_identifier: normalized.requested_identifier,
        canonical_identifier: normalized.canonical_identifier,
        provider: normalized.provider,
        normalized_result: normalized,
        proposed_product_attrs: product_attrs,
        proposed_variant_attrs: variant_attrs,
        format_proposal: format_proposal,
        list_price_proposal: list_price,
        creator_suggestions: creators,
        eligibility_fields: eligibility,
        sale_eligibility_blockers: blockers,
        warnings: warnings,
        unresolved_fields: unresolved
      )
    end

    def proposed_product_attrs(normalized, format_proposal, list_price)
      attrs = {
        name: normalized.title.presence || "Untitled",
        subtitle: normalized.subtitle,
        description: normalized.description,
        product_type: "book",
        product_format_id: format_proposal.product_format_id,
        publisher_or_manufacturer_name: normalized.publisher,
        imprint_or_brand_name: normalized.imprint,
        language_code: normalized.language_code,
        edition_statement: normalized.edition_statement,
        status: "active",
        sellable: false,
        list_price_cents: list_price.persistable? ? list_price.amount_cents : nil
      }

      if normalized.publication_date
        attrs[:publication_date] = normalized.publication_date.date
        attrs[:publication_date_precision] = normalized.publication_date.precision
      end

      attrs
    end

    def format_proposal_for(normalized)
      suggestion = Catalog::MapProductFormat.call(
        organization: @organization, provider_format: normalized.provider_format
      )
      FormatProposal.new(
        product_format_id: suggestion.product_format&.id,
        product_format_name: suggestion.product_format&.name,
        provider_format: normalized.provider_format,
        warning: suggestion.warning
      )
    end

    def list_price_proposal_for(normalized)
      money = normalized.list_price
      return ListPriceProposal.new(
        amount_cents: nil, currency_code: nil, persistable?: false,
        assumed_organization_currency?: false, display_only?: true
      ) if money.nil?

      org_currency = @organization.default_currency_code.to_s.upcase
      currency = money.currency_code
      assumed = currency.blank?
      persistable = currency.blank? || currency == org_currency

      ListPriceProposal.new(
        amount_cents: money.amount_cents,
        currency_code: currency.presence || org_currency,
        persistable?: persistable,
        assumed_organization_currency?: assumed,
        display_only?: true
      )
    end

    def creator_suggestions_for(normalized)
      Array(normalized.creators).map do |creator|
        normalized_name = Catalog::NormalizeCreatorName.call(creator.display_name)
        candidates = @organization.creators.where(active: true, normalized_name: normalized_name).order(:id).to_a

        resolution, matched_id, candidate_ids =
          case candidates.size
          when 0 then [ :propose_create, nil, [] ]
          when 1 then [ :suggest_existing, candidates.first.id, [ candidates.first.id ] ]
          else [ :require_selection, nil, candidates.map(&:id) ]
          end

        CreatorSuggestion.new(
          display_name: creator.display_name,
          role: creator.role,
          credited_as: creator.credited_as,
          position: creator.position,
          resolution: resolution,
          matched_creator_id: matched_id,
          candidate_creator_ids: candidate_ids
        )
      end
    end

    def unresolved_fields_for(product_attrs, format_proposal, creators)
      unresolved = []
      unresolved << "product_format" if product_attrs[:product_format_id].blank?
      unresolved << "title" if product_attrs[:name].blank?
      creators.each do |suggestion|
        unresolved << "creator:#{suggestion.display_name}" if suggestion.resolution == :require_selection
      end
      unresolved << "provider_format" if format_proposal.provider_format.present? && format_proposal.product_format_id.blank?
      unresolved
    end

    def eligibility_fields_for(product_attrs, variant_attrs)
      [
        EligibilityField.new(field: "product_format_id", status: product_attrs[:product_format_id].present? ? :explicit : :missing,
                             value: product_attrs[:product_format_id], source: "enrichment_or_operator"),
        EligibilityField.new(field: "product_type", status: :explicit, value: product_attrs[:product_type], source: "enrichment_default"),
        EligibilityField.new(field: "product_status", status: :explicit, value: product_attrs[:status] || "active", source: "import_default"),
        EligibilityField.new(field: "variant_status", status: :explicit, value: variant_attrs[:status] || "active", source: "import_default"),
        EligibilityField.new(field: "sellable", status: :explicit, value: false, source: "safety_default"),
        EligibilityField.new(field: "purchasable", status: :explicit, value: false, source: "safety_default"),
        EligibilityField.new(field: "inventory_tracking_mode", status: :explicit,
                             value: variant_attrs[:inventory_tracking_mode], source: "operator_default"),
        EligibilityField.new(field: "regular_price_cents", status: :missing, value: nil, source: "operator"),
        EligibilityField.new(field: "merchandise_class_id", status: :missing, value: nil, source: "operator"),
        EligibilityField.new(field: "default_department_id", status: :missing, value: nil, source: "operator"),
        EligibilityField.new(field: "default_tax_category_id", status: :missing, value: nil, source: "operator")
      ]
    end

    def sale_eligibility_blockers_for(product_attrs, variant_attrs)
      return [ "missing_product_format" ] if product_attrs[:product_format_id].blank?

      product = @organization.products.build(
        product_attrs.merge(
          identifier: "0000000000000",
          identifier_generated: false,
          identifier_validation_status: "valid",
          variant_structure: "single"
        )
      )
      variant = product.product_variants.build(variant_attrs)
      Catalog::SaleEligibility.call(variant: variant, store: @store).blockers
    end

    def warning_hash(warning)
      return warning if warning.is_a?(Hash)

      {
        "code" => warning.code,
        "message" => warning.message,
        "details" => warning.details
      }
    end
  end
end
