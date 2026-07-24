# frozen_string_literal: true

module Reporting
  class BuildSessionTotals < ApplicationService
    def initialize(pos_session:, source_cutoff_at: Time.current, recompute_cash: false)
      @pos_session = pos_session
      @source_cutoff_at = source_cutoff_at
      @recompute_cash = recompute_cash
    end

    def call
      session = @pos_session
      txns = completed_transactions(session)
      lines = completed_lines(txns)
      tenders = completed_tenders(txns)
      taxes = completed_taxes(lines)
      void_txn_ids = txns.select { |t| t.reverses_pos_transaction_id.present? }.map(&:id).to_set

      commercial = build_commercial(lines, txns, void_txn_ids)
      tax = build_tax(taxes, lines)
      stored_value = build_stored_value(lines, tenders)
      tender_totals = build_tenders(tenders)
      settlement = build_settlement(commercial, tax, stored_value, tender_totals)
      cash = build_cash(session)
      departments = build_departments(lines, void_txn_ids)
      counts = build_activity_counts(txns, lines, tenders)

      SessionTotals.new(
        report_definition_version: ReportDefinition::VERSION,
        pos_session_id: session.id,
        store_id: session.store_id,
        business_day_id: session.business_day_id,
        business_date: session.business_day.reporting_date,
        source_cutoff_at: @source_cutoff_at,
        identity: build_identity(session),
        commercial: commercial,
        tax: tax,
        stored_value: stored_value,
        settlement: settlement,
        tenders: tender_totals,
        cash: cash,
        departments: departments,
        activity_counts: counts,
        exceptions: []
      )
    end

    private

    def completed_transactions(session)
      PosTransaction
        .where(completed_pos_session_id: session.id, status: "completed")
        .where("completed_at <= ?", @source_cutoff_at)
        .includes(:pos_line_items, :pos_tenders, :reverses_pos_transaction)
    end

    def completed_lines(txns)
      PosLineItem
        .where(pos_transaction_id: txns.map(&:id), status: "completed")
        .where(removed_at: nil)
    end

    def completed_tenders(txns)
      PosTender
        .where(pos_transaction_id: txns.map(&:id), status: "completed")
        .where(removed_at: nil)
        .includes(:tender_type)
    end

    def completed_taxes(lines)
      PosLineItemTax.where(pos_line_item_id: lines.map(&:id)).includes(:store_tax_rate)
    end

    def build_identity(session)
      {
        "store_name" => session.store.name,
        "pos_device_name" => session.pos_device.name,
        "cash_drawer_name" => session.cash_drawer&.name,
        "cashier_username" => session.cashier_user.username,
        "opened_by_username" => session.opened_by_user.username,
        "closed_by_username" => session.closed_by_user&.username,
        "opened_at" => session.opened_at&.iso8601(6),
        "closed_at" => session.closed_at&.iso8601(6),
        "business_date" => session.business_day.reporting_date.iso8601,
        "session_status" => session.status
      }
    end

    def build_commercial(lines, txns, void_txn_ids)
      ordinary_lines = lines.reject { |l| void_txn_ids.include?(l.pos_transaction_id) }
      void_lines = lines.select { |l| void_txn_ids.include?(l.pos_transaction_id) }
      ordinary_txns = txns.reject { |t| void_txn_ids.include?(t.id) }
      void_txns = txns.select { |t| void_txn_ids.include?(t.id) }

      sales = ordinary_lines.select { |l| l.direction == "sale" && l.line_kind != "stored_value" }
      returns = ordinary_lines.select { |l| l.direction == "return" && l.line_kind != "stored_value" }

      gross_sales = sales.sum { |l| l.extended_price_cents.to_i }
      return_total = returns.sum { |l| l.extended_price_cents.to_i }
      discount_total = ordinary_txns.sum { |t| t.discount_total_cents.to_i }
      post_void_commercial_effect = void_txns.sum { |t| transaction_commercial_effect(t, void_lines) }

      sale_cogs = sales.sum { |l| l.cost_extended_cents.to_i }
      return_cogs_reversal = returns.sum { |l| l.cost_extended_cents.to_i }
      post_void_cogs_effect = void_cogs_effect(void_lines)
      net_cogs = sale_cogs - return_cogs_reversal + post_void_cogs_effect

      net_sales = gross_sales - discount_total - return_total + post_void_commercial_effect

      {
        "gross_sales_cents" => gross_sales,
        "discount_total_cents" => discount_total,
        "return_total_cents" => return_total,
        "post_void_count" => void_txns.size,
        "post_void_commercial_effect_cents" => post_void_commercial_effect,
        "net_sales_cents" => net_sales,
        "units_sold" => sales.sum { |l| l.quantity.to_i },
        "units_returned" => returns.sum { |l| l.quantity.to_i },
        "price_override_line_count" => sales.count { |l| l.price_overridden_at.present? },
        "sale_cogs_cents" => sale_cogs,
        "customer_return_cogs_reversal_cents" => return_cogs_reversal,
        "post_void_cogs_effect_cents" => post_void_cogs_effect,
        "net_cogs_cents" => net_cogs,
        "cost_extended_cents" => net_cogs,
        "missing_cost_line_count" => ordinary_lines.count { |l|
          l.line_kind != "stored_value" && l.cost_extended_cents.nil?
        }
      }
    end

    # Sale extended - return extended - discount, using reversing-txn snapshots.
    def transaction_commercial_effect(txn, void_lines)
      txn_lines = void_lines.select { |l| l.pos_transaction_id == txn.id && l.line_kind != "stored_value" }
      sale_ext = txn_lines.select { |l| l.direction == "sale" }.sum { |l| l.extended_price_cents.to_i }
      return_ext = txn_lines.select { |l| l.direction == "return" }.sum { |l| l.extended_price_cents.to_i }
      sale_ext - return_ext - txn.discount_total_cents.to_i
    end

    def void_cogs_effect(void_lines)
      product = void_lines.select { |l| l.line_kind != "stored_value" }
      sale_cogs = product.select { |l| l.direction == "sale" }.sum { |l| l.cost_extended_cents.to_i }
      return_cogs = product.select { |l| l.direction == "return" }.sum { |l| l.cost_extended_cents.to_i }
      sale_cogs - return_cogs
    end

    def build_tax(taxes, lines)
      line_by_id = lines.index_by(&:id)
      components = taxes.group_by(&:store_tax_rate_id).map do |_rate_id, rows|
        rate = rows.first.store_tax_rate
        receipt_code = rows.first.receipt_code_snapshot.presence || rate&.receipt_code.presence || "tax"
        name = rate&.name.presence || receipt_code.presence || "Tax"
        {
          "store_tax_rate_id" => rate&.id,
          "name" => name,
          "receipt_code" => receipt_code,
          "amount_cents" => rows.sum { |tax| signed_tax_amount(tax, line_by_id[tax.pos_line_item_id]) }
        }
      end.sort_by { |row| row["name"].to_s }
      {
        "tax_total_cents" => taxes.sum { |tax| signed_tax_amount(tax, line_by_id[tax.pos_line_item_id]) },
        "components" => components
      }
    end

    # Line-item tax rows store absolute amounts; return / post-void reverse lines negate.
    def signed_tax_amount(tax, line)
      amount = tax.amount_cents.to_i
      line&.direction == "return" ? -amount : amount
    end

    def build_stored_value(lines, tenders)
      sv_lines = lines.select { |l| l.line_kind == "stored_value" }
      issued = sv_lines.select { |l| l.stored_value_operation == "issue" }.sum { |l| l.extended_price_cents.to_i }
      reloaded = sv_lines.select { |l| l.stored_value_operation == "reload" }.sum { |l| l.extended_price_cents.to_i }
      redeemed = tenders.select { |t| t.tender_type.tender_category == "stored_value" && t.direction == "received" }
                       .sum { |t| t.amount_cents.to_i }
      refunded = tenders.select { |t| t.tender_type.tender_category == "stored_value" && t.direction == "refunded" }
                       .sum { |t| t.amount_cents.to_i }

      {
        "issued_cents" => issued,
        "reloaded_cents" => reloaded,
        "redeemed_cents" => redeemed,
        "refunded_cents" => refunded
      }
    end

    def build_tenders(tenders)
      groups = tenders.group_by { |t| t.tender_type.tender_category }
      groups.map do |category, rows|
        received = rows.select { |t| t.direction == "received" }.sum { |t| t.amount_cents.to_i }
        refunded = rows.select { |t| t.direction == "refunded" }.sum { |t| t.amount_cents.to_i }
        {
          "tender_category" => category,
          "received_cents" => received,
          "refunded_cents" => refunded,
          "net_cents" => received - refunded
        }
      end.sort_by { |row| row["tender_category"] }
    end

    def build_settlement(commercial, tax, stored_value, tender_totals)
      net_sales = commercial["net_sales_cents"]
      tax_total = tax["tax_total_cents"]
      sv_liability = stored_value["issued_cents"] + stored_value["reloaded_cents"]
      transaction_total = net_sales + tax_total + sv_liability
      net_tenders = tender_totals.sum { |t| t["net_cents"] }
      {
        "net_sales_cents" => net_sales,
        "net_tax_cents" => tax_total,
        "stored_value_issued_reloaded_cents" => sv_liability,
        "transaction_total_cents" => transaction_total,
        "net_tenders_cents" => net_tenders,
        "balanced" => transaction_total == net_tenders
      }
    end

    def build_cash(session)
      unless session.cash_enabled?
        return {
          "cash_enabled" => false,
          "opening_cash_cents" => nil,
          "expected_cash_cents" => nil,
          "counted_cash_cents" => nil,
          "cash_variance_cents" => nil
        }
      end

      breakdown = Pos::CalculateExpectedCash.call(pos_session: session)
      expected = if !@recompute_cash && session.closed? && session.expected_cash_cents.present?
        session.expected_cash_cents
      else
        breakdown.expected_cash_cents
      end

      {
        "cash_enabled" => true,
        "opening_cash_cents" => breakdown.opening_cash_cents,
        "cash_received_cents" => breakdown.cash_received_cents,
        "change_given_cents" => breakdown.change_given_cents,
        "cash_refunded_cents" => breakdown.cash_refunded_cents,
        "cash_movement_in_cents" => breakdown.cash_movement_in_cents,
        "cash_movement_out_cents" => breakdown.cash_movement_out_cents,
        "expected_cash_cents" => expected,
        "counted_cash_cents" => session.counted_cash_cents,
        "cash_variance_cents" => session.cash_variance_cents
      }
    end

    def build_departments(lines, void_txn_ids)
      product_lines = lines.reject { |l|
        l.line_kind == "stored_value" || void_txn_ids.include?(l.pos_transaction_id)
      }
      dept_meta = Department.where(id: product_lines.map(&:department_id).compact.uniq)
        .pluck(:id, :name, :department_number)
        .to_h { |id, name, number| [ id, { "name" => name, "department_number" => number } ] }
      product_lines.group_by(&:department_id).map do |department_id, rows|
        sales = rows.select { |l| l.direction == "sale" }
        returns = rows.select { |l| l.direction == "return" }
        meta = dept_meta[department_id] || {}
        {
          "department_id" => department_id,
          "department_name" => meta["name"] || "Unassigned",
          "department_number" => meta["department_number"],
          "gross_sales_cents" => sales.sum { |l| l.extended_price_cents.to_i },
          "return_total_cents" => returns.sum { |l| l.extended_price_cents.to_i },
          "units_sold" => sales.sum { |l| l.quantity.to_i }
        }
      end.sort_by { |row| row["department_number"].presence || "~" }
    end

    def build_activity_counts(txns, lines, tenders)
      {
        "completed_transactions" => txns.size,
        "completed_lines" => lines.size,
        "completed_tenders" => tenders.size,
        "post_void_transactions" => txns.count { |t| t.reverses_pos_transaction_id.present? }
      }
    end
  end
end
