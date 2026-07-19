# frozen_string_literal: true

module PosHelper
  def pos_money(cents)
    return "—" if cents.nil?

    format("$%.2f", cents.to_i / 100.0)
  end
end
