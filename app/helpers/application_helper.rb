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
    items = capture(&block)
    return "".html_safe unless items.to_s.include?("nav-item")

    tag.div(class: "nav-section") do
      safe_join([
        tag.h2(title, class: "nav-section-title"),
        tag.ul(items, class: "nav-section-list")
      ])
    end
  end

  def nav_item(label, path, permission_key: nil, match: nil)
    return "".html_safe if permission_key.present? && !nav_permitted?(permission_key)

    active = nav_item_active?(path, match)
    classes = [ "nav-item", ("is-active" if active) ].compact.join(" ")
    opts = { class: classes }
    opts[:"aria-current"] = "page" if active

    tag.li(link_to(label, path, opts))
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

  # Parse user-facing money (`12.95`, `$12.95`) to integer cents. Returns nil if blank/invalid.
  def parse_money_to_cents(value)
    return nil if value.nil?

    str = value.to_s.strip
    return nil if str.blank?

    str = str.delete(",").sub(/\A\$/, "")
    return nil unless str.match?(/\A-?\d+(\.\d{1,2})?\z/)

    (BigDecimal(str) * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def format_cents_as_decimal(cents)
    return "" if cents.nil?

    format("%.2f", cents.to_i / 100.0)
  end

  # `15` or `15%` → basis points (1500). `0.15` treated as fraction only when < 1 and no % sign.
  def parse_percent_to_bps(value)
    return nil if value.nil?

    str = value.to_s.strip
    return nil if str.blank?

    has_percent = str.end_with?("%")
    str = str.delete("%").strip
    return nil unless str.match?(/\A-?\d+(\.\d+)?\z/)

    num = BigDecimal(str)
    if has_percent || num.abs >= 1
      (num * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    else
      (num * 10_000).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end
  end

  def format_bps_as_percent(bps)
    return "" if bps.nil?

    format("%g%%", bps.to_i / 100.0)
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
