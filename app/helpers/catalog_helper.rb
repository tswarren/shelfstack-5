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

  def effective_value_display(resolved)
    return "—" if resolved.nil? || (resolved.value.nil? && resolved.source_label == "Missing")

    value = case resolved.value
    when nil then "—"
    when true then "Yes"
    when false then "No"
    when MerchandiseClass, Department, TaxCategory, ReturnPolicy, ProductFormat
      resolved.value.name
    else
      resolved.value.to_s.tr("_", " ")
    end

    safe_join([
      value,
      " ",
      content_tag(:span, "Source: #{resolved.source_label}", class: "muted")
    ])
  end

  def product_summary_bibliographic_line(identity)
    parts = [
      identity.product_format_name,
      identity.publisher_or_manufacturer_name,
      publication_date_label(identity),
      identity.edition_statement
    ].compact_blank
    parts.presence&.join(" · ")
  end

  def publication_date_label(identity)
    date = identity.respond_to?(:publication_date) ? identity.publication_date : identity
    return if date.blank?

    date.to_fs(:long)
  end

  def language_code_label(code)
    Catalog::LanguageCodes.label_for(code)
  end
end
