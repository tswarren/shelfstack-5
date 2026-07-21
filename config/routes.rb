# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resource :store_selection, only: %i[new create]
  get "no_store_access", to: "no_store_accesses#show", as: :no_store_access

  unless Rails.env.production?
    namespace :development do
      get "ui_gallery", to: "ui_gallery#show", as: :ui_gallery
    end
  end

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
  resources :vendors, except: %i[destroy]
  resources :product_variant_vendors, except: %i[destroy], path: "vendor_sources"
  resources :purchase_orders, except: %i[destroy] do
    member do
      post :place
      post :amend
      post :cancel
      post :close
      post :bulk_discount
    end
  end
  resources :purchase_order_allocations, only: %i[create] do
    member do
      post :release
    end
  end
  resources :receipts, except: %i[destroy] do
    member do
      post :post
      post :cancel
    end
  end
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

  resources :product_requests, except: %i[destroy] do
    member do
      post :assign
      post :resolve
      post :cancel
      post :reserve
    end
  end
  resources :product_imports, only: %i[new create]
  get "buyer_review", to: "buyer_review#index", as: :buyer_review_index
  post "buyer_review/:id/add_to_purchase_order", to: "buyer_review#add_to_purchase_order", as: :add_to_purchase_order

  get "reports", to: "reports#index", as: :reports
  get "reports/open_purchase_orders", to: "reports#open_purchase_orders", as: :open_purchase_orders_report
  get "reports/on_order", to: "reports#on_order", as: :on_order_report
  get "reports/receiving_history", to: "reports#receiving_history", as: :receiving_history_report
  get "reports/customer_requests", to: "reports#customer_requests", as: :customer_requests_report
  get "reports/allocation_events", to: "reports#allocation_events", as: :allocation_events_report

  get "register", to: "register#show", as: :register

  resources :business_days, only: %i[index new create] do
    member do
      post :close
    end
  end
  resources :pos_sessions, only: %i[new create] do
    member do
      get :close_form
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
    resources :pos_return_lines, only: %i[create] do
      collection do
        post :lookup
      end
    end
    resources :pos_discounts, only: %i[create destroy]
    resource :pos_tax_exemption, only: %i[create], controller: "pos_tax_exemptions"
    resources :pos_tenders, only: %i[create destroy]
  end

  root "homes#show"
end
