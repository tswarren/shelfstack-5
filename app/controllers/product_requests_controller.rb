# frozen_string_literal: true

class ProductRequestsController < ApplicationController
  before_action -> { require_permission!("requests.product_request.view") }, only: %i[index show]
  before_action -> { require_permission!("requests.product_request.create") }, only: %i[new create]
  before_action -> { require_permission!("requests.product_request.edit") }, only: %i[edit update]
  before_action -> { require_permission!("requests.product_request.assign") }, only: %i[assign]
  before_action -> { require_permission!("requests.product_request.resolve") }, only: %i[resolve]
  before_action -> { require_permission!("requests.product_request.cancel") }, only: %i[cancel]
  before_action -> { require_permission!("requests.customer_request.reserve") }, only: %i[reserve]
  before_action :set_product_request, only: %i[show edit update assign resolve cancel reserve]

  def index
    scope = Current.store.product_requests.includes(:product, :product_variant, :assigned_buyer_user).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if ProductRequest::STATUSES.include?(params[:status])
    scope = scope.where(request_type: params[:request_type]) if ProductRequest::REQUEST_TYPES.include?(params[:request_type])
    @pagy, @product_requests = pagy(scope, limit: pagy_limit)
  end

  def show
    @buyers = User.joins(:store_memberships)
      .where(store_memberships: { store_id: Current.store.id })
      .distinct.order(:username)

    return unless @product_request.customer_request?

    @can_create_allocation = @product_request.open? && Current.user.can?("purchasing.allocation.create", store: Current.store)
    @can_release_allocation = Current.user.can?("purchasing.allocation.release", store: Current.store)
    @can_reserve = @product_request.open? &&
      @product_request.product_variant_id.present? &&
      Current.user.can?("requests.customer_request.reserve", store: Current.store)
    @allocations = @product_request.purchase_order_allocations
      .includes(purchase_order_line: :purchase_order, purchase_order_allocation_events: [])
      .order(:created_at)
    @active_reservations = InventoryReservation.active
      .where(source_type: "product_request", source_id: @product_request.id)
      .includes(:product_variant, :inventory_unit)

    if @can_reserve && @product_request.product_variant&.inventory_tracking_mode == "individual"
      @available_units = InventoryUnit.where(
        store: Current.store,
        product_variant: @product_request.product_variant,
        status: "available"
      ).order(:unit_identifier)
    end

    if @can_create_allocation
      variant_ids = [ @product_request.product_variant_id ].compact
      variant_scope = variant_ids.any? ? { product_variant_id: variant_ids } : { product_variants: { product_id: @product_request.product_id } }
      @open_purchase_order_lines = PurchaseOrderLine.joins(:purchase_order, :product_variant)
        .where(purchase_orders: { store_id: Current.store.id, status: "ordered" })
        .where(variant_scope)
        .includes(:product_variant, :purchase_order)
        .order("purchase_orders.purchase_order_number", :position)
        .select { |line| line.open_quantity.positive? && @product_request.compatible_with_variant?(line.product_variant) }
    end
  end

  def new
    @product_request = Current.store.product_requests.new(request_type: "customer_request", priority: "normal", requested_quantity: 1)
    load_product_from_params
    load_form_collections
  end

  def create
    @product_request = Current.store.product_requests.new
    result = Requests::CreateProductRequest.call(
      store: Current.store,
      attributes: product_request_params,
      actor: Current.user
    )
    if result.success?
      redirect_to result.product_request, notice: "Product request created."
    else
      @product_request = result.product_request || Current.store.product_requests.new(product_request_params)
      @product_request.errors.add(:base, result.error) if result.error.present? && @product_request.errors.empty?
      load_product_from_params
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return redirect_to @product_request, alert: "Only open requests can be edited." unless @product_request.open?

    load_form_collections
  end

  def update
    result = Requests::UpdateProductRequest.call(
      product_request: @product_request,
      attributes: product_request_params,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      redirect_to result.product_request, notice: "Product request updated."
    else
      @product_request.errors.add(:base, result.error) if result.error.present?
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def assign
    buyer = User.joins(:store_memberships)
      .where(store_memberships: { store_id: Current.store.id })
      .find_by(id: params.dig(:product_request, :assigned_buyer_user_id))
    result = Requests::AssignProductRequest.call(
      product_request: @product_request, assigned_buyer_user: buyer, actor: Current.user, store: Current.store
    )
    if result.success?
      redirect_to result.product_request, notice: "Buyer assigned."
    else
      redirect_to @product_request, alert: result.error
    end
  end

  def resolve
    result = Requests::ResolveProductRequest.call(
      product_request: @product_request,
      resolution: params.dig(:product_request, :resolution),
      resolved_quantity: params.dig(:product_request, :resolved_quantity).presence,
      resolution_note: params.dig(:product_request, :resolution_note),
      create_follow_up: params.dig(:product_request, :create_follow_up),
      follow_up_quantity: params.dig(:product_request, :follow_up_quantity).presence,
      actor: Current.user,
      store: Current.store
    )
    if result.success?
      notice = "Product request resolved."
      notice += " Follow-up request ##{result.follow_up_product_request.id} created." if result.follow_up_product_request
      redirect_to result.product_request, notice: notice
    else
      redirect_to @product_request, alert: result.error
    end
  end

  def cancel
    result = Requests::CancelProductRequest.call(
      product_request: @product_request,
      actor: Current.user,
      store: Current.store,
      cancellation_reason: params.dig(:product_request, :cancellation_reason)
    )
    if result.success?
      redirect_to result.product_request, notice: result.replayed ? "Already cancelled." : "Product request cancelled."
    else
      redirect_to @product_request, alert: result.error
    end
  end

  def reserve
    unit = if params[:inventory_unit_id].present?
      InventoryUnit.find_by(id: params[:inventory_unit_id], store_id: Current.store.id)
    end

    result = Requests::ReserveInHouseInventory.call(
      product_request: @product_request,
      quantity: params[:quantity].presence || 1,
      actor: Current.user,
      store: Current.store,
      physically_confirmed: params[:physically_confirmed],
      inventory_unit: unit
    )
    if result.success?
      redirect_to result.product_request, notice: "Reserved #{params[:quantity].presence || 1} unit(s) for this customer request."
    else
      redirect_to @product_request, alert: result.error
    end
  end

  private

  def set_product_request
    @product_request = Current.store.product_requests.find(params[:id])
  end

  def load_product_from_params
    return if params[:product_id].blank?

    product = Current.organization.products.find_by(id: params[:product_id])
    @product_request.product = product if product
  end

  def load_form_collections
    @buyers = User.joins(:store_memberships)
      .where(store_memberships: { store_id: Current.store.id })
      .distinct.order(:username)
    @products = Current.organization.products.order(:name).limit(200)
    @product_variants = ProductVariant.joins(:product)
      .where(products: { organization_id: Current.organization.id })
      .includes(:product)
      .order("products.name", :name)
  end

  def product_request_params
    params.require(:product_request).permit(
      :request_type, :product_id, :product_variant_id, :requested_quantity, :priority,
      :needed_by_on, :customer_reference, :assigned_buyer_user_id, :notes
    )
  end
end
