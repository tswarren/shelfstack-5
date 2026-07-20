# frozen_string_literal: true

class NoStoreAccessesController < ApplicationController
  layout "authentication"
  skip_store_context

  def show
  end
end
