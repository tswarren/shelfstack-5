# frozen_string_literal: true

class NoStoreAccessesController < ApplicationController
  skip_store_context

  def show
  end
end
