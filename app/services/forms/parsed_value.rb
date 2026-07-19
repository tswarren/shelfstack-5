# frozen_string_literal: true

module Forms
  # Result of parsing a human-facing money or percent form value.
  # status: :blank | :ok | :invalid
  ParsedValue = Data.define(:status, :value, :error, :raw) do
    def blank? = status == :blank
    def ok? = status == :ok
    def invalid? = status == :invalid
  end
end
