# frozen_string_literal: true

# Frame-driven POS overlays. Responses are turbo-frame#pos_overlay fragments.
class PosOverlaysController < ApplicationController
  layout false

  before_action -> { require_permission!("pos.access") }
  before_action :load_register_session!
  before_action :load_transaction!, only: %i[product_lookup line_actions]

  def product_lookup
    @intent = params[:intent].presence || "sale"
  end

  def customer
    return head :forbidden unless can_view_customers?
  end

  def receipt_lookup; end

  def open_ring
    return head :forbidden unless @open_session
    @departments = Department.sorted_hierarchically(
      Current.organization.departments.includes(:parent_department)
    )
  end

  def stored_value
    return head :forbidden unless @open_session
    @sv_operations = []
    @sv_operations << [ "Issue", "issue" ] if Current.user.can?("stored_value.issue", store: Current.store)
    @sv_operations << [ "Reload", "reload" ] if Current.user.can?("stored_value.reload", store: Current.store)
    return head :forbidden if @sv_operations.empty?
  end

  def cash_movement
    return head :forbidden unless @open_session && Current.user.can?("pos.cash_movement.create", store: Current.store)
    @cash_movement_types = Current.organization.cash_movement_types.where(active: true).order(:name)
  end

  def no_sale
    return head :forbidden unless @open_session&.cash_enabled?
  end

  def suspended
    @suspended_transactions = Current.store.pos_transactions.suspended.order(suspended_at: :desc)
  end

  def line_actions
    return head :forbidden unless @pos_transaction&.editable?
    @line = @pos_transaction.pos_line_items.find(params[:line_id])
    @section = params[:section].presence || "discount"
    @entry_intent = params[:intent].presence || "sale"
    @tax_categories = Current.organization.tax_categories.where(active: true).order(:name)
    @discount_reasons = Current.organization.discount_reasons.where(active: true).order(:name)
    @line_discounts_by_line_id = @pos_transaction.pos_discounts
      .where(scope: "line", pos_line_item_id: @line.id)
      .group_by(&:pos_line_item_id)
  end

  private

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
