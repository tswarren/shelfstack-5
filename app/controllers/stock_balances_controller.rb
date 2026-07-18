# frozen_string_literal: true

class StockBalancesController < ApplicationController
  before_action -> { require_permission!("inventory.stock.view") }

  def index
    @stock_balances = Current.store.stock_balances.includes(product_variant: :product).order(:id)
    @can_view_cost = Current.user.can?("inventory.cost.view", store: Current.store)
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
