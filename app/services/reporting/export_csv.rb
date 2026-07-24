# frozen_string_literal: true

require "csv"

module Reporting
  class ExportCsv < ApplicationService
    def initialize(headers:, rows:)
      @headers = headers
      @rows = rows
    end

    def call
      CSV.generate do |csv|
        csv << @headers
        @rows.each { |row| csv << row }
      end
    end
  end
end
