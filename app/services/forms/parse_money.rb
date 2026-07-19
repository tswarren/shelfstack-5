# frozen_string_literal: true

module Forms
  module ParseMoney
    module_function

    # Parses `12.95`, `$12.95`, `12` into integer cents.
    def call(value)
      raw = value
      return Forms::ParsedValue.new(status: :blank, value: nil, error: nil, raw: raw) if value.nil?

      str = value.to_s.strip
      return Forms::ParsedValue.new(status: :blank, value: nil, error: nil, raw: raw) if str.blank?

      normalized = str.delete(",").sub(/\A\$/, "").strip
      unless normalized.match?(/\A-?\d+(\.\d{1,2})?\z/)
        return Forms::ParsedValue.new(status: :invalid, value: nil, error: "is not a valid amount", raw: raw)
      end

      cents = (BigDecimal(normalized) * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
      Forms::ParsedValue.new(status: :ok, value: cents, error: nil, raw: raw)
    end
  end
end
