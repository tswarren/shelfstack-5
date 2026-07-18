# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resource :store_selection, only: %i[new create]
  get "no_store_access", to: "no_store_accesses#show", as: :no_store_access

  root "homes#show"
end
