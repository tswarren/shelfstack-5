# frozen_string_literal: true

require "digest"
require "json"

module Pos
  # Canonical commercial snapshot for a card-refund preparation. Fingerprint
  # detects drift; the stored JSON explains what was authorized at the terminal.
  class RefundPlanSnapshot
    VERSION = PosCardRefundPreparation::FINGERPRINT_VERSION

    def self.build(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      intended_original_pos_tender: nil,
      pos_approval: nil,
      net_total_cents:,
      refund_due_cents:
    )
      new(
        pos_transaction: pos_transaction,
        tender_type: tender_type,
        amount_cents: amount_cents,
        actor: actor,
        intended_original_pos_tender: intended_original_pos_tender,
        pos_approval: pos_approval,
        net_total_cents: net_total_cents,
        refund_due_cents: refund_due_cents
      ).to_h
    end

    def self.fingerprint(snapshot)
      canonical = JSON.generate(deep_sort(snapshot))
      Digest::SHA256.hexdigest(canonical)
    end

    def self.deep_sort(value)
      case value
      when Hash
        value.keys.sort.index_with { |key| deep_sort(value[key]) }
      when Array
        value.map { |item| deep_sort(item) }
      else
        value
      end
    end

    def initialize(
      pos_transaction:,
      tender_type:,
      amount_cents:,
      actor:,
      intended_original_pos_tender:,
      pos_approval:,
      net_total_cents:,
      refund_due_cents:
    )
      @transaction = pos_transaction
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @actor = actor
      @intended_original = intended_original_pos_tender
      @pos_approval = pos_approval
      @net_total_cents = net_total_cents.to_i
      @refund_due_cents = refund_due_cents.to_i
    end

    def to_h
      {
        "schema_version" => VERSION,
        "transaction_id" => @transaction.id,
        "store_id" => @transaction.store_id,
        "tender_type_id" => @tender_type.id,
        "amount_cents" => @amount_cents,
        "intended_original_pos_tender_id" => @intended_original&.id,
        "requester_user_id" => @actor.id,
        "pos_approval_id" => @pos_approval&.id,
        "net_total_cents" => @net_total_cents,
        "refund_due_cents" => @refund_due_cents,
        "pending_return_lines" => pending_return_lines,
        "unresolved_refund_tenders" => unresolved_refund_tenders,
        "linked_original_tenders" => linked_original_tenders
      }
    end

    private

    def pending_return_lines
      @transaction.pos_line_items.pending.returns.order(:id).map { |line|
        {
          "id" => line.id,
          "original_pos_line_item_id" => line.original_pos_line_item_id,
          "quantity" => line.quantity,
          "extended_price_cents" => line.extended_price_cents,
          "tax_amount_cents" => line.tax_amount_cents
        }
      }
    end

    def unresolved_refund_tenders
      @transaction.pos_tenders.unresolved.where(direction: "refunded").order(:id).map { |tender|
        {
          "id" => tender.id,
          "destination" => RefundAllocationPolicy.destination_for(tender)&.to_s,
          "amount_cents" => tender.amount_cents,
          "original_pos_tender_id" => tender.original_pos_tender_id,
          "tender_category" => tender.tender_type.tender_category
        }
      }
    end

    def linked_original_tenders
      RefundAllocationPolicy.remaining_original_tenders(@transaction).sort_by(&:id).map { |tender|
        completed_refund = tender.refund_tenders.where(status: "completed").sum(:amount_cents)
        in_flight = tender.refund_tenders.where(status: %w[pending authorized]).sum(:amount_cents)
        {
          "id" => tender.id,
          "amount_cents" => tender.amount_cents,
          "completed_refund_amount_cents" => completed_refund,
          "in_flight_refund_amount_cents" => in_flight,
          "remaining_refundable_cents" => tender.remaining_refundable_cents,
          "tender_category" => tender.tender_type.tender_category
        }
      }
    end
  end
end
