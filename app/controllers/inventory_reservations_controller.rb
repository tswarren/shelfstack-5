# frozen_string_literal: true

class InventoryReservationsController < ApplicationController
  before_action -> { require_permission!("inventory.reservation.view") }, only: %i[index]
  before_action -> { require_permission!("inventory.reservation.release") }, only: %i[release]
  before_action :set_reservation, only: %i[release]

  STATUS_FILTERS = %w[active released].freeze

  def index
    @status = params[:status].to_s.presence_in(STATUS_FILTERS)
    scope = InventoryReservation.where(store_id: Current.store.id)
      .includes(product_variant: :product)
      .order(Arel.sql("CASE status WHEN 'active' THEN 0 ELSE 1 END"), reserved_at: :desc)
    scope = scope.where(status: @status) if @status
    @pagy, @inventory_reservations = pagy(scope, limit: pagy_limit)
  end

  def release
    result = Inventory::ReleaseReservation.call(
      reservation: @inventory_reservation,
      actor: Current.user,
      release_reason: params[:release_reason]
    )
    if result.success?
      redirect_to inventory_reservations_path, notice: result.replayed ? "Already released." : "Reservation released."
    else
      redirect_to inventory_reservations_path, alert: result.error
    end
  end

  private

  def set_reservation
    @inventory_reservation = InventoryReservation.where(store_id: Current.store.id).find(params[:id])
  end
end
