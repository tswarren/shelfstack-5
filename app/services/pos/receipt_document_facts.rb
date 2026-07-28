# frozen_string_literal: true

module Pos
  # Read-only completed-transaction facts for browser receipt documents.
  # Does not call pricing, tax, promotion, return, or inventory calculation services.
  class ReceiptDocumentFacts
    Result = Data.define(
      :pos_transaction,
      :lines,
      :tenders,
      :tax_components,
      :tax_markers_by_line_id,
      :tax_legend,
      :register_label,
      :cashier_label,
      :linked_return_receipt_numbers,
      :original_transaction,
      :reversing_transaction,
      :post_voided,
      :masked_customer_label,
      :barcode,
      :reprint,
      :reprint_at,
      :store,
      :merchandise_cents,
      :refund_cents,
      :non_merchandise_cents,
      :discount_total_cents,
      :subtotal_cents,
      :change_due_cents,
      :items_sold_count,
      :items_returned_count,
      :total_savings_cents,
      :stored_value_details_by_line_id,
      :stored_value_tender_details_by_tender_id
    )

    COLLECTING_TREATMENTS = %w[taxable zero_rated].freeze
    NONTAXABLE_RECEIPT_CODE = "N"
    NONTAXABLE_LEGEND_NAME = "Nontaxable"

    def self.call(pos_transaction:, store:, reprint: false, reprint_at: nil)
      new(pos_transaction:, store:, reprint:, reprint_at:).call
    end

    def initialize(pos_transaction:, store:, reprint: false, reprint_at: nil)
      @pos_transaction = pos_transaction
      @store = store
      @reprint = reprint
      @reprint_at = reprint_at
    end

    def call
      lines = load_lines
      tax_components = tax_components_for(lines)
      names_by_code = current_rate_names_by_code(tax_components.map { |c| c[:code] })
      tax_components = tax_components.map do |component|
        component.merge(name: names_by_code[component[:code]])
      end
      markers_by_line = tax_markers_by_line_id(lines)
      breakdown = totals_breakdown(lines)
      tenders = load_tenders

      Result.new(
        pos_transaction: @pos_transaction,
        lines: lines,
        tenders: tenders,
        tax_components: tax_components,
        tax_markers_by_line_id: markers_by_line,
        tax_legend: tax_legend_for(tax_components, names_by_code, markers_by_line),
        register_label: register_label,
        cashier_label: cashier_label,
        linked_return_receipt_numbers: linked_return_receipt_numbers(lines),
        original_transaction: @pos_transaction.reverses_pos_transaction,
        reversing_transaction: @pos_transaction.post_void_transaction,
        post_voided: @pos_transaction.post_voided?,
        masked_customer_label: masked_customer_label,
        barcode: ReceiptBarcode.call(receipt_number: @pos_transaction.receipt_number),
        reprint: @reprint,
        reprint_at: @reprint ? (@reprint_at || Time.current) : nil,
        store: @store,
        merchandise_cents: breakdown.fetch(:merchandise_cents),
        refund_cents: breakdown.fetch(:refund_cents),
        non_merchandise_cents: breakdown.fetch(:non_merchandise_cents),
        discount_total_cents: breakdown.fetch(:discount_total_cents),
        subtotal_cents: breakdown.fetch(:subtotal_cents),
        change_due_cents: tenders.sum { |tender| tender.change_due_cents.to_i },
        items_sold_count: breakdown.fetch(:items_sold_count),
        items_returned_count: breakdown.fetch(:items_returned_count),
        total_savings_cents: breakdown.fetch(:discount_total_cents),
        stored_value_details_by_line_id: stored_value_details_by_line_id(lines),
        stored_value_tender_details_by_tender_id: stored_value_tender_details_by_tender_id(tenders)
      )
    end

    private

    def load_lines
      @pos_transaction.pos_line_items
        .where(status: "completed")
        .includes(
          { product_variant: :product },
          { pos_discount_allocations: { pos_discount: :discount_reason } },
          :pos_line_item_taxes,
          :department,
          :stored_value_account,
          :stored_value_entries,
          { original_pos_line_item: :pos_transaction }
        )
        .order(:position, :id)
        .to_a
    end

    def load_tenders
      @pos_transaction.pos_tenders
        .where(status: "completed")
        .includes(:tender_type, :stored_value_account, :stored_value_entries)
        .order(:created_at, :id)
        .to_a
    end

    def register_label
      session_record = @pos_transaction.completed_pos_session || @pos_transaction.origin_pos_session
      session_record&.pos_device&.name
    end

    def cashier_label
      user = @pos_transaction.cashier_user
      return nil if user.blank?

      [ user.first_name, user.last_name ].compact_blank.join(" ").presence || user.username
    end

    def linked_return_receipt_numbers(lines)
      lines
        .select(&:return?)
        .filter_map { |line| line.original_pos_line_item&.pos_transaction&.receipt_number }
        .uniq
    end

    def masked_customer_label
      customer = @pos_transaction.customer
      return nil if customer.blank?

      number = customer.customer_number.to_s
      return "Customer ****" if number.length < 4

      "Customer **** #{number[-4, 4]}"
    end

    def totals_breakdown(lines)
      merchandise_cents = 0
      refund_cents = 0
      non_merchandise_cents = 0
      discount_total_cents = 0
      items_sold_count = 0
      items_returned_count = 0

      lines.each do |line|
        discount_cents = line_discount_cents(line)
        discount_total_cents += discount_cents if line.sale?
        net = line_net_cents(line, discount_cents:)

        if line.return?
          refund_cents += net
          items_returned_count += line.quantity.to_i
        elsif line.line_kind == "stored_value"
          non_merchandise_cents += net
        else
          merchandise_cents += net
          items_sold_count += line.quantity.to_i
        end
      end

      {
        merchandise_cents: merchandise_cents,
        refund_cents: refund_cents,
        non_merchandise_cents: non_merchandise_cents,
        discount_total_cents: discount_total_cents,
        subtotal_cents: merchandise_cents + refund_cents + non_merchandise_cents,
        items_sold_count: items_sold_count,
        items_returned_count: items_returned_count
      }
    end

    def line_discount_cents(line)
      line.pos_discount_allocations.sum { |allocation| allocation.allocated_amount_cents.to_i }
    end

    def line_net_cents(line, discount_cents: nil)
      discount_cents = line_discount_cents(line) if discount_cents.nil?
      net = line.extended_price_cents.to_i - discount_cents
      line.return? ? -net : net
    end

    def stored_value_details_by_line_id(lines)
      lines.each_with_object({}) do |line, hash|
        next unless line.line_kind == "stored_value"

        account = line.stored_value_account
        entry = line.stored_value_entries.max_by(&:id)
        number = account&.account_number.presence || line.stored_value_account_number_snapshot
        hash[line.id] = {
          masked_account: masked_account_number(number),
          new_balance_cents: balance_after_entry(account, entry)
        }
      end
    end

    def stored_value_tender_details_by_tender_id(tenders)
      tenders.each_with_object({}) do |tender, hash|
        next unless tender.tender_type&.tender_category == "stored_value"
        next unless tender.direction == "received"

        account = tender.stored_value_account
        entry = tender.stored_value_entries.max_by(&:id)
        remaining = balance_after_entry(account, entry)
        next if remaining.nil?

        hash[tender.id] = { remaining_balance_cents: remaining }
      end
    end

    def masked_account_number(number)
      text = number.to_s
      return nil if text.blank?
      return "****" if text.length < 4

      "****#{text[-4, 4]}"
    end

    def balance_after_entry(account, entry)
      return nil if account.blank? || entry.blank?

      StoredValueEntry
        .where(stored_value_account_id: account.id)
        .where("id <= ?", entry.id)
        .sum(:amount_cents)
    end

    def tax_components_for(lines)
      entries = lines.flat_map do |line|
        sign = line.return? ? -1 : 1
        line.pos_line_item_taxes
          .select { |tax| collecting_tax?(tax) }
          .map { |tax| [ tax, sign ] }
      end
      return [] if entries.empty?

      entries
        .group_by { |tax, _sign| tax.receipt_code_snapshot.presence || "Tax" }
        .map do |code, group|
          rate = group.map { |tax, _sign| tax.rate }.compact.first
          amount_cents = group.sum { |tax, sign| tax.amount_cents.to_i * sign }
          taxable_amount_cents = group.sum { |tax, sign| tax.taxable_amount_cents.to_i * sign }
          {
            code: code,
            rate: rate,
            taxable_amount_cents: taxable_amount_cents,
            amount_cents: amount_cents
          }
        end
        .reject { |component| component[:amount_cents].zero? && component[:code] == "Tax" }
    end

    def tax_markers_by_line_id(lines)
      lines.each_with_object({}) do |line, hash|
        codes = line.pos_line_item_taxes
          .select { |tax| collecting_tax?(tax) }
          .filter_map { |tax| tax.receipt_code_snapshot.presence }
          .uniq
        hash[line.id] = codes.presence || [ NONTAXABLE_RECEIPT_CODE ]
      end
    end

    def tax_legend_for(tax_components, names_by_code, markers_by_line)
      codes = (
        tax_components.map { |component| component[:code] } +
        markers_by_line.values.flatten
      ).compact.uniq

      codes.map do |code|
        if code == NONTAXABLE_RECEIPT_CODE
          { code: code, name: NONTAXABLE_LEGEND_NAME }
        else
          { code: code, name: names_by_code[code].presence || code }
        end
      end
    end

    def current_rate_names_by_code(codes)
      unique_codes = codes.compact_blank.uniq
      return {} if unique_codes.empty?

      StoreTaxRate
        .where(store_id: @store.id, receipt_code: unique_codes)
        .pluck(:receipt_code, :name)
        .to_h
    end

    def collecting_tax?(tax)
      COLLECTING_TREATMENTS.include?(tax.treatment_snapshot.to_s)
    end
  end
end
