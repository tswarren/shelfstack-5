# frozen_string_literal: true

require "digest"
require "json"

module Pos
  # Commercial identity of a completed sale used to detect drift between
  # post-void approval and terminal submission.
  class PostVoidPlanSnapshot
    VERSION = PosPostVoidPreparation::FINGERPRINT_VERSION

    def self.build(original_transaction)
      lines = original_transaction.pos_line_items.where(status: "completed").order(:id).map { |line|
        {
          "id" => line.id,
          "product_variant_id" => line.product_variant_id,
          "quantity" => line.quantity,
          "extended_price_cents" => line.extended_price_cents,
          "cost_extended_cents" => line.cost_extended_cents,
          "line_kind" => line.line_kind,
          "direction" => line.direction
        }
      }
      tenders = original_transaction.pos_tenders.where(status: "completed").order(:id).map { |tender|
        {
          "id" => tender.id,
          "tender_type_id" => tender.tender_type_id,
          "amount_cents" => tender.amount_cents,
          "amount_tendered_cents" => tender.amount_tendered_cents
        }
      }

      {
        "version" => VERSION,
        "original_pos_transaction_id" => original_transaction.id,
        "receipt_number" => original_transaction.receipt_number,
        "net_total_cents" => original_transaction.net_total_cents,
        "tax_total_cents" => original_transaction.tax_total_cents,
        "lines" => lines,
        "tenders" => tenders
      }
    end

    def self.fingerprint(snapshot)
      Digest::SHA256.hexdigest(JSON.generate(RefundPlanSnapshot.deep_sort(snapshot)))
    end
  end
end
