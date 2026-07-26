# frozen_string_literal: true

module CatalogHelper
  SALE_ELIGIBILITY_BLOCKER_LABELS = {
    "product_inactive" => "Product is not active",
    "product_not_sellable" => "Product is not marked sellable",
    "product_outside_availability_window" => "Product is outside its availability window",
    "variant_inactive" => "Standard item is not active",
    "variant_not_sellable" => "Standard item is not marked sellable",
    "variant_outside_availability_window" => "Standard item is outside its availability window",
    "missing_price" => "Selling price is missing",
    "missing_tracking_mode" => "Inventory tracking mode is missing",
    "missing_merchandise_class" => "Merchandise class is missing",
    "merchandise_class_inactive" => "Merchandise class is inactive",
    "missing_department" => "Department is missing",
    "department_inactive" => "Department is inactive",
    "department_not_postable" => "Department is not postable",
    "missing_tax_category" => "Tax category is missing",
    "tax_category_inactive" => "Tax category is inactive",
    "missing_product_type" => "Product type is missing",
    "missing_product_format" => "Product format is missing",
    "unsupported_variant_structure" => "Variant structure is not supported for sale"
  }.freeze

  def sale_eligibility_blocker_label(code)
    key = code.to_s
    SALE_ELIGIBILITY_BLOCKER_LABELS.fetch(key) { key.tr("_", " ").capitalize }
  end

  LONG_DESCRIPTION_CHARS = 280

  def effective_value_display(resolved)
    return "—" if resolved.nil? || (resolved.value.nil? && resolved.source_label == "Missing")

    value = effective_value_label(resolved)
    safe_join([ value, " ", effective_value_provenance(resolved) ])
  end

  def effective_value_label(resolved)
    return "—" if resolved.nil? || (resolved.value.nil? && resolved.source_label == "Missing")

    case resolved.value
    when nil then "—"
    when true then "Yes"
    when false then "No"
    when MerchandiseClass, Department, TaxCategory, ReturnPolicy, ProductFormat
      resolved.value.name
    else
      resolved.value.to_s.tr("_", " ")
    end
  end

  # Visible source label + decorative icon + visually-hidden detail (not title-only).
  def effective_value_provenance(resolved)
    return "".html_safe if resolved.nil?

    detail = "Source: #{resolved.source_label}"
    content_tag(:span, class: "provenance") do
      safe_join([
        content_tag(:span, resolved.source_label, class: "provenance-label muted"),
        " ",
        icon_tag("info", class: "provenance-icon"),
        content_tag(:span, detail, class: "sr-only")
      ])
    end
  end

  def product_summary_bibliographic_line(identity)
    parts = [
      identity.product_format_name,
      identity.publisher_or_manufacturer_name,
      publication_date_label(identity)
    ].compact_blank
    parts.presence&.join(" · ")
  end

  def product_creator_byline(identity)
    return if identity.creators.blank?

    identity.creators.map(&:display_name).join(", ")
  end

  def product_price_display_rows(list_price_cents:, regular_price_cents:)
    rows = []
    if list_price_cents.present? && regular_price_cents.present?
      if list_price_cents == regular_price_cents
        rows << [ "Selling price", format_money(regular_price_cents) ]
      else
        rows << [ "List price", format_money(list_price_cents) ]
        rows << [ "Selling price", format_money(regular_price_cents) ]
      end
    elsif regular_price_cents.present?
      rows << [ "Selling price", format_money(regular_price_cents) ]
    elsif list_price_cents.present?
      rows << [ "List price", format_money(list_price_cents) ]
    end
    rows
  end

  def long_description?(text)
    normalized_description_length(text) > LONG_DESCRIPTION_CHARS
  end

  def normalized_description_length(text)
    ActionController::Base.helpers.strip_tags(text.to_s).gsub(/\s+/, " ").strip.length
  end

  def suppress_product_identity_field?(field, identity)
    case field.to_sym
    when :alternate_identifier then identity.alternate_identifier.blank?
    when :edition_statement then identity.edition_statement.blank?
    when :imprint_or_brand_name then identity.imprint_or_brand_name.blank?
    when :language_code
      identity.language_code.blank? ||
        Catalog::LanguageCodes.normalize(identity.language_code) == Catalog::LanguageCodes::DEFAULT
    else
      false
    end
  end

  def publication_date_label(identity)
    date = identity.respond_to?(:publication_date) ? identity.publication_date : identity
    return if date.blank?

    date.to_fs(:long)
  end

  def language_code_label(code)
    Catalog::LanguageCodes.label_for(code)
  end

  def merchandise_class_breadcrumb(merchandise_class)
    return if merchandise_class.blank?

    hierarchy_path_label(merchandise_class)
  end
end
