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
  namespace :catalog do
    get "record_searches", to: "record_searches#index", as: :record_searches
  end
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
  resources :stored_value_accounts, only: %i[index show new create] do
    member do
      post :adjust
    end
  end
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

  get "reconciliations", to: "reconciliations#index", as: :reconciliations
  get "reconciliations/sessions/:pos_session_id", to: "reconciliations#session_show", as: :session_reconciliation
  get "reconciliations/business_days/:business_day_id", to: "reconciliations#business_day_show", as: :business_day_reconciliation
  post "reconciliations/:id/finalize", to: "reconciliations#finalize", as: :finalize_reconciliation
  post "reconciliations/:id/comparisons/:comparison_id/accept_unavailable", to: "reconciliations#accept_unavailable", as: :accept_unavailable_comparison
  post "reconciliations/:id/comparisons/:comparison_id/resolutions", to: "reconciliations#record_resolution", as: :record_reconciliation_resolution

  get "reports", to: "reports#index", as: :reports
  get "reports/open_purchase_orders", to: "reports#open_purchase_orders", as: :open_purchase_orders_report
  get "reports/on_order", to: "reports#on_order", as: :on_order_report
  get "reports/receiving_history", to: "reports#receiving_history", as: :receiving_history_report
  get "reports/customer_requests", to: "reports#customer_requests", as: :customer_requests_report
  get "reports/allocation_events", to: "reports#allocation_events", as: :allocation_events_report
  get "reports/commercial_activity", to: "reports#commercial_activity", as: :commercial_activity_report
  get "reports/tender_activity", to: "reports#tender_activity", as: :tender_activity_report
  get "reports/tax_activity", to: "reports#tax_activity", as: :tax_activity_report
  get "reports/stock_snapshot", to: "reports#stock_snapshot", as: :stock_snapshot_report
  get "reports/stored_value_liability", to: "reports#stored_value_liability", as: :stored_value_liability_report
  get "reports/integrity_diagnostics", to: "reports#integrity_diagnostics", as: :integrity_diagnostics_report
  get "reports/export", to: "reports#export", as: :export_report

  get "register", to: "register#show", as: :register
  post "register/scan_to_start", to: "register#scan_to_start", as: :register_scan_to_start
  post "register/lookup_receipt", to: "register#lookup_receipt", as: :register_lookup_receipt

  resources :business_days, only: %i[index new create] do
    member do
      get :close_form
      post :close
      get :x_report, to: "business_day_reports#x", as: :business_day_x_report
      get :z_report, to: "business_day_reports#z", as: :business_day_z_report
    end
  end
  resources :pos_sessions, only: %i[new create] do
    member do
      get :close_form
      post :close
      get :x_report, to: "session_reports#x", as: :session_x_report
      get :z_report, to: "session_reports#z", as: :session_z_report
    end
    resources :pos_cash_movements, only: %i[create]
  end
  resources :pos_transactions, only: %i[index show create] do
    member do
      post :suspend
      post :recall
      post :cancel
      post :complete
      post :start_linked_return
      get :tender
      get :post_void_form
      post :approve_post_void
      post :clear_post_void_approval
      post :post_void
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
    resources :pos_tenders, only: %i[create destroy] do
      member do
        post :confirm_void
      end
    end
  end

  root "homes#show"
end
