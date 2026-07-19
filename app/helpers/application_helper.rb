# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def page_title(title, browser_title: nil)
    content_for(:title, browser_title.presence || title)
    tag.h1(title)
  end

  def nav_permitted?(permission_key)
    Current.permission?(permission_key)
  end

  def nav_section(title, &block)
    items = capture(&block).to_s
    return "".html_safe unless items.include?("nav-item")

    tag.div(class: "nav-section") do
      safe_join([
        tag.h2(title, class: "nav-section-title"),
        tag.ul(items.html_safe, class: "nav-section-list")
      ])
    end
  end

  def nav_item(label, path, permission_key: nil, match: nil)
    return "".html_safe if permission_key.present? && !nav_permitted?(permission_key)

    active = nav_item_active?(path, match)
    link_opts = { class: [ "nav-item", ("is-active" if active) ].compact.join(" ") }
    link_opts[:"aria-current"] = "page" if active

    tag.li(link_to(label, path, link_opts))
  end

  def status_badge(text, variant: :neutral)
    render "shared/status_badge", text: text, variant: variant
  end

  def boolean_status(value, true_label: "Active", false_label: "Inactive")
    if value
      status_badge(true_label, variant: :success)
    else
      status_badge(false_label, variant: :inactive)
    end
  end

  # active/inactive/discontinued lifecycle used by catalog products and variants.
  def product_status_variant(status)
    case status.to_s
    when "active" then :success
    when "discontinued" then :warning
    else :inactive
    end
  end

  def adjustment_status_variant(status)
    case status.to_s
    when "posted" then :success
    when "cancelled" then :danger
    else :info
    end
  end

  def reservation_status_variant(status)
    case status.to_s
    when "active" then :info
    when "converted" then :success
    else :neutral
    end
  end

  def inventory_unit_status_variant(status)
    case status.to_s
    when "available" then :success
    when "reserved" then :info
    when "sold" then :neutral
    when "damaged", "discarded" then :danger
    else :warning
    end
  end

  def cost_quality_variant(quality)
    case quality.to_s
    when "actual" then :success
    when "estimated" then :warning
    when "unknown" then :danger
    else :neutral
    end
  end

  def formatted_datetime(value, format: :long)
    return "—" if value.blank?

    l(value, format: format)
  end

  def record_identifier(record)
    return "—" if record.blank?

    if record.respond_to?(:code) && record.code.present?
      record.code
    elsif record.respond_to?(:public_id) && record.public_id.present?
      record.public_id
    elsif record.respond_to?(:sku) && record.sku.present?
      record.sku
    else
      "##{record.id}"
    end
  end

  # Parse user-facing money (`12.95`, `$12.95`) to integer cents.
  # Prefer Forms::ParseMoney in controllers when blank/invalid must be distinguished.
  def parse_money_to_cents(value)
    Forms::ParseMoney.call(value).value
  end

  def format_cents_as_decimal(cents)
    return "" if cents.nil?

    format("%.2f", cents.to_i / 100.0)
  end

  def format_money(cents, currency_code: nil)
    return "—" if cents.nil?

    code = (currency_code.presence || Current.store&.currency_code.presence || "USD").to_s
    amount = cents.to_i / 100.0
    begin
      ActionController::Base.helpers.number_to_currency(amount, unit: currency_unit(code), format: "%u%n")
    rescue StandardError
      format("%s%.2f", currency_unit(code), amount)
    end
  end

  def currency_unit(code)
    case code.to_s.upcase
    when "USD" then "$"
    when "CAD" then "CA$"
    when "GBP" then "£"
    when "EUR" then "€"
    else "#{code} "
    end
  end

  # Always percentage points for UI: `0.5` → 50 bps (0.5%), `15` → 1500 bps.
  # Prefer Forms::ParsePercent in controllers when blank/invalid must be distinguished.
  def parse_percent_to_bps(value)
    Forms::ParsePercent.to_bps(value).value
  end

  def format_bps_as_percent(bps)
    return "" if bps.nil?

    format("%g%%", bps.to_i / 100.0)
  end

  # Prefer Forms::ParsePercent in controllers when blank/invalid must be distinguished.
  def parse_percent_to_rate(value)
    Forms::ParsePercent.to_rate(value).value
  end

  # Format a decimal-fraction rate (`0.13`) as a percent string (`13%`).
  def format_rate_as_percent(rate)
    return "" if rate.nil?

    format_bps_as_percent((BigDecimal(rate.to_s) * 10_000).round)
  end

  def field_error_id(object_name, method)
    "#{object_name}_#{method}_error"
  end

  def field_hint_id(object_name, method)
    "#{object_name}_#{method}_hint"
  end

  def field_describedby(object_name, method, object: nil, hint: false)
    ids = []
    ids << field_hint_id(object_name, method) if hint
    if object&.errors&.include?(method)
      ids << field_error_id(object_name, method)
    end
    ids.presence&.join(" ")
  end

  # Propshaft serves each CSS file with a digest. Link the ShelfStack sheets
  # explicitly — bare `@import` paths in application.css 404 in the browser.
  def shelfstack_stylesheet_tags
    stylesheet_link_tag(
      "shelfstack/tokens",
      "shelfstack/base",
      "shelfstack/shell",
      "shelfstack/components",
      "shelfstack/forms",
      "shelfstack/tables",
      "shelfstack/patterns",
      "shelfstack/pos",
      "application",
      "data-turbo-track": "reload"
    )
  end

  private

  def nav_item_active?(path, match)
    case match
    when :exact
      request.path == path
    when Regexp
      request.path.match?(match)
    when String
      request.path.start_with?(match)
    else
      request.path == path || (path != root_path && request.path.start_with?(path))
    end
  end
end
