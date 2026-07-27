# frozen_string_literal: true

# Frame-driven POS overlays. Responses are turbo-frame#pos_overlay fragments.
class PosOverlaysController < ApplicationController
  layout false

  before_action -> { require_permission!("pos.access") }
  before_action :load_register_session!
  before_action :load_transaction!, only: %i[product_lookup line_actions receipt_detail]

  def product_lookup
    @intent = params[:intent].presence || "sale"
  end

  def customer
    head :forbidden unless can_view_customers?
  end

  def receipt_lookup; end

  def receipt_detail
    return head :not_found if @pos_transaction.blank?
    return head :forbidden unless @pos_transaction.completed?

    @pos_line_items = @pos_transaction.pos_line_items.where.not(status: "removed").order(:position, :id)
    @line_discount_cents_by_id = @pos_line_items.to_h { |line| [ line.id, line.discount_amount_cents.to_i ] }
    @line_tax_cents_by_id = @pos_line_items.to_h { |line| [ line.id, line.tax_amount_cents.to_i ] }
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
    head :forbidden unless @open_session&.cash_enabled?
  end

  def suspended
    @suspended_transactions = Current.store.pos_transactions.suspended.order(suspended_at: :desc)
  end

  def line_actions
    return head :forbidden unless @pos_transaction&.editable?

    @line = @pos_transaction.pos_line_items.find(params[:line_id])
    @section = params[:section].presence || "discount"
    unless line_action_section_allowed?(@section, @line)
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

  def line_action_section_allowed?(section, line)
    return false if line.line_kind == "stored_value"
    return false unless %w[discount price tax].include?(section)
    return false if section == "price" && line.line_kind != "product"

    true
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
