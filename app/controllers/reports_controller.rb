# frozen_string_literal: true

# Read-only operational and Phase 7 report-pack projections over posted facts.
# Reporting consumes posted source records; it never modifies them (AGENTS.md §4).
class ReportsController < ApplicationController
  OnOrderRow = Data.define(:product_variant, :on_order_quantity)

  before_action :require_any_report_access!, only: %i[index]
  before_action -> { require_permission!("purchasing.purchase_order.view") }, only: %i[open_purchase_orders on_order allocation_events]
  before_action -> { require_permission!("inventory.receipt.view") }, only: %i[receiving_history]
  before_action -> { require_permission!("requests.product_request.view") }, only: %i[customer_requests]
  before_action -> { require_permission!("reporting.view_sales") }, only: %i[commercial_activity]
  before_action -> { require_permission!("reporting.view_tenders") }, only: %i[tender_activity]
  before_action -> { require_permission!("reporting.view_tax") }, only: %i[tax_activity]
  before_action -> { require_permission!("reporting.view_inventory") }, only: %i[stock_snapshot]
  before_action -> { require_permission!("reporting.view_stored_value") }, only: %i[stored_value_liability]
  before_action -> { require_permission!("reporting.view_audit") }, only: %i[integrity_diagnostics]
  before_action -> { require_permission!("reporting.export") }, only: %i[export]

  def index
    @can_view_purchase_orders = Current.user.can?("purchasing.purchase_order.view", store: Current.store)
    @can_view_receipts = Current.user.can?("inventory.receipt.view", store: Current.store)
    @can_view_requests = Current.user.can?("requests.product_request.view", store: Current.store)
    @can_view_sales = Current.user.can?("reporting.view_sales", store: Current.store)
    @can_view_tenders = Current.user.can?("reporting.view_tenders", store: Current.store)
    @can_view_tax = Current.user.can?("reporting.view_tax", store: Current.store)
    @can_view_inventory = Current.user.can?("reporting.view_inventory", store: Current.store)
    @can_view_stored_value = Current.user.can?("reporting.view_stored_value", store: Current.store)
    @can_view_audit = Current.user.can?("reporting.view_audit", store: Current.store)
    @can_reconcile = Current.user.can?("reporting.reconcile_session", store: Current.store) ||
      Current.user.can?("reporting.reconcile_business_day", store: Current.store)
  end

  def open_purchase_orders
    scope = Current.store.purchase_orders.where(status: %w[draft ordered])
      .includes(:vendor, :purchase_order_lines).order(created_at: :desc)
    @pagy, @purchase_orders = pagy(scope, limit: pagy_limit)
    @can_view_cost = Current.user.can?("purchasing.cost.view", store: Current.store) ||
      Current.user.can?("reporting.view_cost", store: Current.store)
  end

  def on_order
    variant_ids = PurchaseOrderLine.joins(:purchase_order)
      .where(purchase_orders: { store_id: Current.store.id, status: "ordered" })
      .distinct.pluck(:product_variant_id)
    variants = ProductVariant.where(id: variant_ids).includes(:product)

    @rows = variants.map { |variant| OnOrderRow.new(variant, Purchasing::OnOrder.call(store: Current.store, product_variant: variant)) }
      .select { |row| row.on_order_quantity.positive? }
      .sort_by { |row| -row.on_order_quantity }
  end

  def receiving_history
    receipt_scope = Current.store.receipts.includes(:vendor).order(created_at: :desc)
    @pagy, @receipts = pagy(receipt_scope, limit: pagy_limit)
    @can_view_cost = Current.user.can?("inventory.cost.view", store: Current.store) ||
      Current.user.can?("purchasing.cost.view", store: Current.store) ||
      Current.user.can?("reporting.view_cost", store: Current.store)

    return unless Current.user.can?("purchasing.purchase_order.view", store: Current.store)

    @partially_received_orders = Current.store.purchase_orders.where(status: "ordered")
      .includes(:vendor, :purchase_order_lines)
      .select { |po| po.receiving_state == "partially_received" }
  end

  def customer_requests
    scope = Current.store.product_requests.where(request_type: "customer_request")
      .includes(:product, :product_variant).order(created_at: :desc)
    @pagy, @product_requests = pagy(scope, limit: pagy_limit)
  end

  def allocation_events
    scope = PurchaseOrderAllocationEvent
      .joins(purchase_order_allocation: { purchase_order_line: :purchase_order })
      .where(purchase_orders: { store_id: Current.store.id })
      .includes(purchase_order_allocation: [ :product_request, { purchase_order_line: [ :product_variant, :purchase_order ] } ], user: [])
      .order(occurred_at: :desc, id: :desc)
    @pagy, @events = pagy(scope, limit: pagy_limit)
  end

  def commercial_activity
    @from_date, @to_date = report_date_range
    @rows = Reporting::CommercialActivityReport.call(store: Current.store, from_date: @from_date, to_date: @to_date)
    @show_cost = Current.user.can?("reporting.view_cost", store: Current.store)
    @show_margin = Current.user.can?("reporting.view_margin", store: Current.store)
  end

  def tender_activity
    @from_date, @to_date = report_date_range
    @rows = Reporting::TenderActivityReport.call(store: Current.store, from_date: @from_date, to_date: @to_date)
  end

  def tax_activity
    @from_date, @to_date = report_date_range
    @rows = Reporting::TaxActivityReport.call(store: Current.store, from_date: @from_date, to_date: @to_date)
  end

  def stock_snapshot
    @rows = Reporting::StockSnapshotReport.call(store: Current.store)
    @show_cost = Current.user.can?("reporting.view_cost", store: Current.store)
  end

  def stored_value_liability
    @report = Reporting::StoredValueLiabilityReport.call(
      organization: Current.store.organization,
      store: Current.store
    )
  end

  def integrity_diagnostics
    @findings = Reporting::IntegrityDiagnostics.call(store: Current.store)
  end

  def export
    report = params[:report].to_s
    from_date, to_date = report_date_range
    csv, filename = build_export(report, from_date, to_date)
    Administration::RecordAuditEvent.call(
      actor: Current.user,
      organization: Current.store.organization,
      store: Current.store,
      action: "reporting.csv_exported",
      subject: Current.store,
      metadata: { "report" => report, "from_date" => from_date.iso8601, "to_date" => to_date.iso8601 }
    )
    send_data csv, filename: filename, type: "text/csv"
  end

  private

  def require_any_report_access!
    allowed = %w[
      purchasing.purchase_order.view inventory.receipt.view requests.product_request.view
      reporting.view_sales reporting.view_tenders reporting.view_tax reporting.view_inventory
      reporting.view_stored_value reporting.view_audit
      reporting.reconcile_session reporting.reconcile_business_day
    ].any? { |key| Current.user.can?(key, store: Current.store) }
    return if allowed

    redirect_to root_path, alert: "You are not authorized to perform that action."
  end

  def report_date_range
    from_date = params[:from_date].presence&.to_date || StoreTime.today(Current.store) - 7
    to_date = params[:to_date].presence&.to_date || StoreTime.today(Current.store)
    [ from_date, to_date ]
  end

  def build_export(report, from_date, to_date)
    case report
    when "commercial_activity"
      require_permission!("reporting.view_sales")
      rows = Reporting::CommercialActivityReport.call(store: Current.store, from_date: from_date, to_date: to_date)
      csv = Reporting::ExportCsv.call(
        headers: %w[date gross_sales_cents discount_total_cents return_total_cents net_sales_cents units_sold],
        rows: rows.map { |r| [ r.completed_on, r.gross_sales_cents, r.discount_total_cents, r.return_total_cents, r.net_sales_cents, r.units_sold ] }
      )
      [ csv, "commercial_activity_#{from_date}_#{to_date}.csv" ]
    when "tender_activity"
      require_permission!("reporting.view_tenders")
      rows = Reporting::TenderActivityReport.call(store: Current.store, from_date: from_date, to_date: to_date)
      csv = Reporting::ExportCsv.call(
        headers: %w[tender_category received_cents refunded_cents net_cents],
        rows: rows.map { |r| [ r.tender_category, r.received_cents, r.refunded_cents, r.net_cents ] }
      )
      [ csv, "tender_activity_#{from_date}_#{to_date}.csv" ]
    else
      raise ArgumentError, "unsupported export"
    end
  end
end
