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
  resources :tax_categories, except: %i[destroy]
  resources :store_tax_rates, except: %i[show destroy]
  resources :store_tax_rules, except: %i[show destroy]
  resources :return_policies, except: %i[destroy]
  resources :return_reasons, except: %i[destroy]
  resources :discount_reasons, except: %i[destroy]
  resources :departments, except: %i[destroy]
  resources :merchandise_classes, except: %i[destroy]
  resources :product_formats, except: %i[destroy]
  resources :product_conditions, except: %i[destroy]
  resources :products, except: %i[destroy]
  resources :inventory_adjustment_reasons, except: %i[destroy]
  resources :stock_balances, only: %i[index show]
  resources :inventory_adjustments, except: %i[destroy] do
    member do
      post :post
      post :cancel
    end
  end
  resources :inventory_reservations, only: %i[index] do
    member do
      post :release
    end
  end
  resources :inventory_units, only: %i[index show new create]

  get "register", to: "register#show", as: :register

  resources :business_days, only: %i[index new create] do
    member do
      post :close
    end
  end
  resources :pos_sessions, only: %i[new create] do
    member do
      post :close
    end
    resources :pos_cash_movements, only: %i[create]
  end
  resources :pos_transactions, only: %i[index show create] do
    member do
      post :suspend
      post :recall
      post :cancel
      post :complete
    end
    resources :pos_line_items, only: %i[create update destroy] do
      member do
        patch :override_price
        patch :override_tax_category
      end
    end
    resources :pos_return_lines, only: %i[create]
    resources :pos_discounts, only: %i[create]
    resource :pos_tax_exemption, only: %i[create], controller: "pos_tax_exemptions"
    resources :pos_tenders, only: %i[create destroy]
  end

  root "homes#show"
end
