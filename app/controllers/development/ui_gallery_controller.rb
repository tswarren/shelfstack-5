# frozen_string_literal: true

module Development
  class UiGalleryController < ApplicationController
    before_action :ensure_non_production!

    def show
    end

    private

    def ensure_non_production!
      return unless Rails.env.production?

      raise ActionController::RoutingError, "Not Found"
    end
  end
end
