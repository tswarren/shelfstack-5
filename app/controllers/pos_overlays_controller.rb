# frozen_string_literal: true

# Frame-driven POS overlays. Responses are turbo-frame#pos_overlay fragments.
class PosOverlaysController < ApplicationController
  layout false

  before_action -> { require_permission!("pos.access") }
  before_action :load_register_session!
  before_action :load_transaction!, only: %i[product_lookup line_actions receipt_detail transaction_lines]

  def product_lookup
    @intent = params[:intent].presence || "sale"
    @query = params[:q].to_s.strip
    @view_only = %w[tender recovery].include?(params[:presentation].to_s)
    @lookup_results = if @query.present?
      Pos::ProductLookupResults.call(
        organization: Current.organization,
        store: Current.store,
        query: @query
      )
    else
      Pos::ProductLookupResults::Result.new(query: @query, groups: [], inventory_unit: nil)
    end
  end

  def transaction_lines
    return head :not_found if @pos_transaction.blank?

    @entry_intent = params[:intent].presence || "sale"
    @pos_line_items = @pos_transaction.pos_line_items.where.not(status: "removed").order(:position, :id)
  end

  def customer
    head :forbidden unless can_view_customers?
  end

  def customer_create
    return head :forbidden unless Current.user.can?("customers.customer.create", store: Current.store)

    @customer = Current.organization.customers.new(
      customer_type: "individual",
      preferred_contact_method: "none",
      country_code: Current.store&.country_code,
      region: Current.store&.region,
      active: true
    )
    @possible_duplicates = []
  end

  def pickup
    return head :forbidden unless @open_session
    return head :forbidden unless Current.user.can?("pos.product_request.pickup", store: Current.store) ||
      Current.user.can?("requests.product_request.view", store: Current.store)

    @pickup_query = params[:q].to_s.strip
    scope = Current.store.product_requests.open_requests
      .where(request_type: "customer_request")
      .includes(:product, :product_variant, :customer)
      .order(:created_at)
    if @pickup_query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@pickup_query)}%"
      scope = scope.left_joins(:customer).where(
        "product_requests.id::text = :exact OR customers.customer_number ILIKE :q OR " \
        "customers.first_name ILIKE :q OR customers.last_name ILIKE :q OR " \
        "customers.organization_name ILIKE :q",
        exact: @pickup_query, q: pattern
      )
    else
      scope = scope.none
    end

    @fulfillable_customer_requests = scope.limit(25).select { |request| request.outstanding_quantity.positive? }
  end

  def receipt_lookup; end

  def start_return
    return head :forbidden unless Current.user.can?("pos.return.create", store: Current.store)

    @return_reasons = Current.organization.return_reasons.where(active: true).order(:name)
    @tax_categories = Current.organization.tax_categories.where(active: true).order(:name)
  end

  def receipt_detail
    return head :not_found if @pos_transaction.blank?
    return head :forbidden unless @pos_transaction.completed?

    @pos_line_items = @pos_transaction.pos_line_items.where.not(status: "removed").order(:position, :id)
    snapshots = Pos::LineFinancialSnapshots.call(pos_line_item_ids: @pos_line_items.map(&:id))
    @line_discount_cents_by_id = snapshots.discount_cents_by_id
    @line_tax_cents_by_id = snapshots.tax_cents_by_id
    @subtotal_cents = @pos_transaction.subtotal_cents || 0
    @discount_total_cents = @pos_transaction.discount_total_cents || 0
    @tax_total_cents = @pos_transaction.tax_total_cents || 0
    @net_total_cents = @pos_transaction.net_total_cents || 0
    received = @pos_transaction.pos_tenders.where(status: "completed", direction: "received").sum(:amount_cents)
    refunded = @pos_transaction.pos_tenders.where(status: "completed", direction: "refunded").sum(:amount_cents)
    @tendered_total_cents = received - refunded
  end

  def open_ring
    return head :forbidden unless @open_session

    @departments = Department.sorted_hierarchically(
      Current.organization.departments.includes(:parent_department)
    ).select { |department| department.active? && department.postable? }
  end

  def stored_value
    return head :forbidden unless @open_session

    @sv_operations = []
    @sv_operations << [ "Issue", "issue" ] if Current.user.can?("stored_value.issue", store: Current.store)
    @sv_operations << [ "Reload", "reload" ] if Current.user.can?("stored_value.reload", store: Current.store)
    head :forbidden if @sv_operations.empty?
  end

  def cash_movement
    return head :forbidden unless @open_session && Current.user.can?("pos.cash_movement.create", store: Current.store)

    @cash_movement_types = Current.organization.cash_movement_types.where(active: true).order(:name)
  end

  def no_sale
    head :forbidden unless @open_session&.cash_enabled? &&
      Current.user.can?("pos.no_sale.create", store: Current.store)
  end

  def suspended
    @suspended_transactions = Current.store.pos_transactions.suspended.order(suspended_at: :desc)
  end

  def line_actions
    return head :forbidden unless @pos_transaction&.editable?

    @line = @pos_transaction.pos_line_items.find(params[:line_id])
    @section = params[:section].presence || "discount"
    @line_actions = Pos::LineActions.new(user: Current.user, store: Current.store, line: @line)
    unless line_action_section_allowed?(@section, @line, @line_actions)
      return render :unsupported_line_action, status: :unprocessable_entity
    end

    @entry_intent = params[:intent].presence || "sale"
    @tax_categories = Current.organization.tax_categories.where(active: true).order(:name)
    @discount_reasons = Current.organization.discount_reasons.where(active: true).order(:name)
    @line_discounts_by_line_id = @pos_transaction.pos_discounts
      .where(scope: "line", target_pos_line_item_id: @line.id)
      .group_by(&:target_pos_line_item_id)
  end

  private

  def line_action_section_allowed?(section, line, line_actions = nil)
    return false if line.line_kind == "stored_value"
    return false unless %w[discount price tax].include?(section)
    return false if section == "price" && line.line_kind != "product"

    actions = line_actions || Pos::LineActions.new(user: Current.user, store: Current.store, line: line)
    case section
    when "discount" then actions.discount_available?
    when "price" then actions.price_override_available?
    when "tax" then actions.tax_override_available?
    else false
    end
  end

  def load_register_session!
    business_day = Current.store.business_days.find_by(status: "open")
    @open_session = business_day && Current.store.pos_sessions.open_sessions
      .find_by(cashier_user: Current.user)
  end

  def load_transaction!
    return if params[:pos_transaction_id].blank?

    @pos_transaction = Current.store.pos_transactions.find(params[:pos_transaction_id])
  end

  def can_view_customers?
    Current.user.can?("customers.customer.view", store: Current.store) ||
      Current.user.can?("customers.customer.lookup", store: Current.store)
  end
end
