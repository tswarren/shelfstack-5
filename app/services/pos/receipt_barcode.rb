# frozen_string_literal: true

require "barby"
require "barby/barcode/code_128"
require "barby/outputter/svg_outputter"

module Pos
  # Renders a Code 128 barcode SVG for a public receipt_number.
  # Failure returns a Result with svg: nil so the document remains printable.
  class ReceiptBarcode
    Result = Data.define(:svg, :payload, :error)

    def self.call(receipt_number:)
      new(receipt_number:).call
    end

    def initialize(receipt_number:)
      @receipt_number = receipt_number.to_s
    end

    def call
      if @receipt_number.blank?
        return Result.new(svg: nil, payload: @receipt_number, error: "blank receipt number")
      end

      barcode = Barby::Code128B.new(@receipt_number)
      svg = +Barby::SvgOutputter.new(barcode).to_svg(xdim: 2, height: 50)
      svg.sub!(/\A<\?xml[^>]*>\s*/m, "")
      Result.new(svg: svg, payload: @receipt_number, error: nil)
    rescue StandardError => e
      Result.new(svg: nil, payload: @receipt_number, error: e.message)
    end
  end
end
