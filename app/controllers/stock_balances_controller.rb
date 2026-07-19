# frozen_string_literal: true

class StockBalancesController < ApplicationController
  before_action -> { require_permission!("inventory.stock.view") }

  AVAILABILITY_FILTERS = %w[in_stock out_of_stock negative].freeze

  def index
    @query = params[:q].to_s.strip
    @availability = params[:availability].to_s.presence_in(AVAILABILITY_FILTERS)
    @can_view_cost = Current.user.can?("inventory.cost.view", store: Current.store)

    scope = Current.store.stock_balances
      .joins(product_variant: :product)
      .includes(product_variant: :product)
      .order("product_variants.sku")

    if @query.present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      scope = scope.where(
        "product_variants.sku ILIKE :q OR product_variants.name ILIKE :q OR products.name ILIKE :q",
        q: like
      )
    end

    case @availability
    when "in_stock"     then scope = scope.where("on_hand - reserved - unavailable > 0")
    when "out_of_stock" then scope = scope.where("on_hand - reserved - unavailable <= 0")
    when "negative"     then scope = scope.where("on_hand < 0")
    end

    @pagy, @stock_balances = pagy(scope, limit: pagy_limit)
  end

  def show
    @stock_balance = Current.store.stock_balances.find(params[:id])
    @can_view_cost = Current.user.can?("inventory.cost.view", store: Current.store)
    @ledger_entries = InventoryLedgerEntry.where(
      store_id: Current.store.id,
      product_variant_id: @stock_balance.product_variant_id
    ).order(posted_at: :desc, id: :desc).limit(50)
  end
end
