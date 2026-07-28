# frozen_string_literal: true

require "barby"
require "barby/barcode/ean_13"
require "barby/outputter/svg_outputter"

module StoredValue
  # Renders an EAN-13 barcode SVG for a canonical stored-value account number.
  # Failure returns svg: nil so the Credit Voucher remains printable.
  class AccountBarcode
    Result = Data.define(:svg, :payload, :error)

    def self.call(account_number:)
      new(account_number:).call
    end

    def initialize(account_number:)
      @account_number = account_number.to_s
    end

    def call
      if @account_number.blank?
        return Result.new(svg: nil, payload: @account_number, error: "blank account number")
      end

      # Barby::EAN13 expects the 12-digit body and appends the check digit.
      body = @account_number.length == 13 ? @account_number[0, 12] : @account_number
      barcode = Barby::EAN13.new(body)
      rendered = barcode.to_s
      if @account_number.length == 13 && rendered != @account_number
        return Result.new(svg: nil, payload: @account_number, error: "account number checksum mismatch")
      end

      svg = +Barby::SvgOutputter.new(barcode).to_svg(xdim: 2, height: 50)
      svg.sub!(/\A<\?xml[^>]*>\s*/m, "")
      Result.new(svg: svg, payload: @account_number.presence || rendered, error: nil)
    rescue StandardError => e
      Result.new(svg: nil, payload: @account_number, error: e.message)
    end
  end
end
