# frozen_string_literal: true

class PermissionsController < ApplicationController
  before_action -> { require_permission!("administration.store.view") }

  def index
    @permissions = Permission.order(:code)
  end
end
