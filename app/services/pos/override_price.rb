# frozen_string_literal: true

module Pos
  # Price Override is distinct from Discount (domain "Pricing and Discounts"): it
  # directly changes the line's effective selling price rather than creating a
  # Discount/Allocation. Scoped to Product lines with a catalog Regular Price; the
  # override rate (regular -> requested reduction) gates `maximum_price_override_rate`
  # authority. Requests at or above the Regular Price are markups/corrections and
  # need only the base `pos.price.override` permission.
  class OverridePrice < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings, :pos_approval)

    def initialize(pos_line_item:, requested_unit_price_cents:, actor:, reason: nil, approver: nil, approver_pin: nil)
      @pos_line_item = pos_line_item
      @requested_unit_price_cents = requested_unit_price_cents.to_i
      @actor = actor
      @reason = reason
      @approver = approver
      @approver_pin = approver_pin
    end

    def call
      raise Error, "line is not pending" unless @pos_line_item.pending?
      raise Error, "transaction is not open for editing" unless @pos_line_item.pos_transaction.editable?
      raise Error, "price must not be negative" if @requested_unit_price_cents.negative?
      raise Error, "price override applies only to product lines" unless @pos_line_item.line_kind == "product"
      raise Error, "cannot override price on a linked return line" if @pos_line_item.return?

      regular_price_cents = @pos_line_item.product_variant.regular_price_cents
      raise Error, "product variant has no regular price to override" if regular_price_cents.blank?

      store = @pos_line_item.pos_transaction.store
      authorization = Pos::AuthorizeAction.call(
        store: store,
        requester: @actor,
        permission_key: "pos.price.override",
        approver_permission_key: "pos.price.override",
        action_type: "price_override",
        limit_key: :maximum_price_override_rate,
        requested_value: override_rate(regular_price_cents),
        reason: @reason,
        approver: @approver,
        approver_pin: @approver_pin,
        pos_transaction: @pos_line_item.pos_transaction,
        pos_line_item: @pos_line_item,
        pos_session: @pos_line_item.pos_transaction.active_pos_session
      )
      return unauthorized_result(authorization) unless authorization.allowed?

      ActiveRecord::Base.transaction do
        # Canonical order: transaction before line (matches completion lock order).
        transaction = PosTransaction.lock.find(@pos_line_item.pos_transaction_id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        line = PosLineItem.lock.find(@pos_line_item.id)
        raise Error, "line is not pending" unless line.pending?
        raise Error, "line does not belong to the locked transaction" unless line.pos_transaction_id == transaction.id

        line.update!(
          unit_price_cents: @requested_unit_price_cents,
          price_overridden_at: Time.current,
          price_overridden_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "pos_line_item.price_overridden",
          subject: line,
          metadata: {
            "regular_price_cents" => regular_price_cents,
            "requested_unit_price_cents" => @requested_unit_price_cents,
            "reason" => @reason,
            "approved_by_user_id" => authorization.pos_approval&.approved_by_user_id
          }
        )

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)

        Result.new(pos_line_item: line, success?: true, error: nil, warnings: recalculation.blockers + recalculation.warnings,
                   pos_approval: authorization.pos_approval)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [], pos_approval: nil)
    end

    private

    def override_rate(regular_price_cents)
      return 0 if regular_price_cents.zero? || @requested_unit_price_cents >= regular_price_cents

      BigDecimal(regular_price_cents - @requested_unit_price_cents) / BigDecimal(regular_price_cents)
    end

    def unauthorized_result(authorization)
      error = case authorization.status
      when :requires_approval then "price override exceeds authority and requires approval"
      else authorization.error || "price override denied"
      end
      Result.new(pos_line_item: nil, success?: false, error: error, warnings: [], pos_approval: nil)
    end
  end
end
