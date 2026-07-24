# frozen_string_literal: true

module Catalog
  # Test-only delayed search endpoint for stale-response system coverage.
  class SlowRecordSearchesController < ApplicationController
    def index
      raise ActionController::RoutingError, "Not Found" unless Rails.env.test?

      sleep(0.6)
      render json: {
        results: [
          { id: 9_999_001, label: "STALE RESULT SHOULD NOT APPEAR", status: "active", inactive: false }
        ]
      }
    end
  end
end
