# frozen_string_literal: true

module InventoryHelper
  def inventory_money(cents, quality: nil)
    return "unknown" if quality.to_s == "unknown" || cents.nil?

    format_money(cents)
  end
end
