# frozen_string_literal: true

module Inventory
  module Rounding
    module_function

    # Deterministic round-half-up for integer cents.
    def round_half_up(numerator, denominator)
      raise ArgumentError, "denominator must be positive" if denominator.to_i <= 0

      num = numerator.to_d
      den = denominator.to_d
      (num / den).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def multiply_round_half_up(unit_cents, quantity)
      (unit_cents.to_d * quantity.to_i).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end
  end
end
