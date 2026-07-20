# frozen_string_literal: true

module Pos
  # Removes a provisional Discount from an editable Transaction. Allocations are
  # deleted with the Discount; completed Transactions retain their Discount rows
  # and this service refuses to mutate them.
  class RemoveDiscount < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_discount, :success?, :error, :warnings)

    def initialize(pos_discount:, actor:)
      @pos_discount = pos_discount
      @actor = actor
    end

    def call
      raise Error, "discount is missing" if @pos_discount.blank?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_discount.pos_transaction_id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        discount = PosDiscount.lock.find(@pos_discount.id)
        raise Error, "discount does not belong to the locked transaction" unless discount.pos_transaction_id == transaction.id
        if discount.target_pos_line_item&.return?
          raise Error, "historical return discount reversals cannot be removed"
        end

        store = transaction.store
        metadata = {
          "scope" => discount.scope,
          "method" => discount.method,
          "applied_amount_cents" => discount.applied_amount_cents,
          "target_pos_line_item_id" => discount.target_pos_line_item_id,
          "pos_discount_id" => discount.id
        }

        # Allocations FK is ON DELETE RESTRICT; delete children first, then the
        # discount row (skip association callbacks that try to nullify the FK).
        PosDiscountAllocation.where(pos_discount_id: discount.id).delete_all
        PosDiscount.where(id: discount.id).delete_all

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "pos_discount.removed",
          subject: transaction,
          metadata: metadata
        )

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)

        Result.new(pos_discount: discount, success?: true, error: nil,
                   warnings: (recalculation.blockers + recalculation.warnings).uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Result.new(pos_discount: nil, success?: false, error: e.message, warnings: [])
    end
  end
end
