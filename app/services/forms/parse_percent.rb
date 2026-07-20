# frozen_string_literal: true

module Forms
  module ParsePercent
    module_function

    # Always interprets input as percentage points for UI forms.
    # `0.5` / `0.5%` → 50 bps (0.5%); `15` / `15%` → 1500 bps.
    def to_bps(value)
      raw = value
      return Forms::ParsedValue.new(status: :blank, value: nil, error: nil, raw: raw) if value.nil?

      str = value.to_s.strip
      return Forms::ParsedValue.new(status: :blank, value: nil, error: nil, raw: raw) if str.blank?

      str = str.delete("%").strip
      unless str.match?(/\A-?\d+(\.\d+)?\z/)
        return Forms::ParsedValue.new(status: :invalid, value: nil, error: "is not a valid percentage", raw: raw)
      end

      bps = (BigDecimal(str) * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
      Forms::ParsedValue.new(status: :ok, value: bps, error: nil, raw: raw)
    end

    def to_rate(value)
      parsed = to_bps(value)
      return parsed if parsed.blank? || parsed.invalid?

      rate = BigDecimal(parsed.value.to_s) / 10_000
      Forms::ParsedValue.new(status: :ok, value: rate, error: nil, raw: parsed.raw)
    end

    # Legacy: treat values with abs < 1 and no % as 0–1 fractions. Not for UI forms.
    def fraction_to_bps(value)
      raw = value
      return Forms::ParsedValue.new(status: :blank, value: nil, error: nil, raw: raw) if value.nil?

      str = value.to_s.strip
      return Forms::ParsedValue.new(status: :blank, value: nil, error: nil, raw: raw) if str.blank?

      has_percent = str.end_with?("%")
      str = str.delete("%").strip
      unless str.match?(/\A-?\d+(\.\d+)?\z/)
        return Forms::ParsedValue.new(status: :invalid, value: nil, error: "is not a valid percentage", raw: raw)
      end

      num = BigDecimal(str)
      bps = if has_percent || num.abs >= 1
        (num * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
      else
        (num * 10_000).round(0, BigDecimal::ROUND_HALF_UP).to_i
      end
      Forms::ParsedValue.new(status: :ok, value: bps, error: nil, raw: raw)
    end
  end
end
