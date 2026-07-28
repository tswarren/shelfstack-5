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
      :store
    )

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
      Result.new(
        pos_transaction: @pos_transaction,
        lines: lines,
        tenders: load_tenders,
        tax_components: tax_components_for(lines),
        register_label: register_label,
        cashier_label: @pos_transaction.cashier_user&.username,
        linked_return_receipt_numbers: linked_return_receipt_numbers(lines),
        original_transaction: @pos_transaction.reverses_pos_transaction,
        reversing_transaction: @pos_transaction.post_void_transaction,
        post_voided: @pos_transaction.post_voided?,
        masked_customer_label: masked_customer_label,
        barcode: ReceiptBarcode.call(receipt_number: @pos_transaction.receipt_number),
        reprint: @reprint,
        reprint_at: @reprint ? (@reprint_at || Time.current) : nil,
        store: @store
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
          { original_pos_line_item: :pos_transaction }
        )
        .order(:position, :id)
        .to_a
    end

    def load_tenders
      @pos_transaction.pos_tenders
        .where(status: "completed")
        .includes(:tender_type)
        .order(:created_at, :id)
        .to_a
    end

    def register_label
      session_record = @pos_transaction.completed_pos_session || @pos_transaction.origin_pos_session
      session_record&.pos_device&.name
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

    def tax_components_for(lines)
      taxes = lines.flat_map(&:pos_line_item_taxes)
      return [] if taxes.empty?

      taxes
        .group_by { |tax| tax.receipt_code_snapshot.presence || "Tax" }
        .map do |code, group|
          rate = group.map(&:rate).compact.first
          label = if rate.present?
            "#{code} #{format("%g", rate.to_f * 100)}%"
          else
            code
          end
          { label: label, amount_cents: group.sum { |tax| tax.amount_cents.to_i } }
        end
        .reject { |component| component[:amount_cents].zero? && component[:label] == "Tax" }
    end
  end
end
