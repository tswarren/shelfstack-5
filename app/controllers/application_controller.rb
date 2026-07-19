# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend

  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from Pagy::OverflowError, with: :redirect_to_last_page

  private

  # Clamp the requested page size: default 25, maximum 100.
  def pagy_limit
    requested = params[:limit].to_i
    return Pagy::DEFAULT[:limit] if requested <= 0

    requested.clamp(1, 100)
  end

  # Preserve search/filter params (`q`, etc.) while redirecting an
  # out-of-range page request to the last available page.
  def redirect_to_last_page(error)
    last_page_params = request.query_parameters.merge(page: error.pagy.last)
    redirect_to "#{request.path}?#{last_page_params.to_query}"
  end
end
