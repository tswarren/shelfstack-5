# frozen_string_literal: true

module Pos
  # Changing a line's effective Tax Category is a restricted, audited action
  # (`pos.tax_category.override`), distinct from ordinary line editing (domain "Tax
  # Category override"). Retains the first pre-override Tax Category, override
  # reason, actor, and timestamp.
  class OverrideTaxCategory < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_line_item, :success?, :error, :warnings, :pos_approval)

    def initialize(pos_line_item:, tax_category:, reason:, actor:, approver: nil, approver_pin: nil)
      @pos_line_item = pos_line_item
      @tax_category = tax_category
      @reason = reason
      @actor = actor
      @approver = approver
      @approver_pin = approver_pin
    end

    def call
      raise Error, "line is not pending" unless @pos_line_item.pending?
      raise Error, "transaction is not open for editing" unless @pos_line_item.pos_transaction.editable?
      raise Error, "tax category is required" if @tax_category.blank?
      raise Error, "override reason is required" if @reason.blank?
      raise Error, "cannot override tax category on a linked return line" if @pos_line_item.return?

      store = @pos_line_item.pos_transaction.store
      unless @tax_category.organization_id == store.organization_id
        raise Error, "tax category must belong to the transaction's organization"
      end

      authorization = Pos::AuthorizeAction.call(
        store: store,
        requester: @actor,
        permission_key: "pos.tax_category.override",
        approver_permission_key: "pos.tax_category.override",
        action_type: "tax_category_override",
        reason: @reason,
        approver: @approver,
        approver_pin: @approver_pin,
        pos_transaction: @pos_line_item.pos_transaction,
        pos_line_item: @pos_line_item,
        pos_session: @pos_line_item.pos_transaction.active_pos_session
      )
      return unauthorized_result(authorization) unless authorization.allowed?

      ActiveRecord::Base.transaction do
        line = PosLineItem.lock.find(@pos_line_item.id)
        raise Error, "line is not pending" unless line.pending?
        raise Error, "transaction is not open for editing" unless line.pos_transaction.editable?

        original_tax_category_id = line.original_tax_category_id || line.tax_category_id
        line.update!(
          tax_category: @tax_category,
          original_tax_category_id: original_tax_category_id,
          tax_category_overridden_at: Time.current,
          tax_category_overridden_by_user: @actor,
          tax_category_override_reason: @reason
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "pos_line_item.tax_category_overridden",
          subject: line,
          metadata: {
            "original_tax_category_id" => original_tax_category_id,
            "tax_category_id" => @tax_category.id,
            "reason" => @reason,
            "approved_by_user_id" => authorization.pos_approval&.approved_by_user_id
          }
        )

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: line.pos_transaction)

        Result.new(pos_line_item: line, success?: true, error: nil, warnings: recalculation.blockers + recalculation.warnings,
                   pos_approval: authorization.pos_approval)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_item: nil, success?: false, error: e.message, warnings: [], pos_approval: nil)
    end

    private

    def unauthorized_result(authorization)
      error = case authorization.status
      when :requires_approval then "tax category override requires approval"
      else authorization.error || "tax category override denied"
      end
      Result.new(pos_line_item: nil, success?: false, error: error, warnings: [], pos_approval: nil)
    end
  end
end
