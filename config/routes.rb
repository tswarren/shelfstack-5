# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resource :store_selection, only: %i[new create]
  get "no_store_access", to: "no_store_accesses#show", as: :no_store_access

  resources :stores, except: %i[destroy]
  resources :users, except: %i[destroy]
  resources :roles, except: %i[destroy]
  resources :permissions, only: %i[index]
  resources :administrative_audit_events, only: %i[index], path: "audit_events"
  resources :store_memberships, except: %i[show destroy]
  resources :pos_devices, except: %i[show destroy]
  resources :cash_drawers, except: %i[show destroy]

  root "homes#show"
end
