# frozen_string_literal: true

module Customers
  # True when the actor may search/associate Customers (full view or narrow lookup).
  class AuthorizeLookup < ApplicationService
    PERMISSIONS = %w[customers.customer.view customers.customer.lookup].freeze

    def initialize(user:, store:)
      @user = user
      @store = store
    end

    def call
      return false if @user.blank? || @store.blank?

      PERMISSIONS.any? do |key|
        Authorization::EvaluatePermission.call(user: @user, store: @store, permission_key: key) == :allow
      end
    end
  end
end
