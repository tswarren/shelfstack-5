# frozen_string_literal: true

module Pos
  # Phase 4b Tax Exemptions cover only `whole_transaction` (domain "Tax Exemptions");
  # selected-line / selected-component coverage is deferred. One exemption per
  # Transaction — applying again is a no-op success against the existing record.
  class ApplyTaxExemption < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_tax_exemption, :success?, :error, :warnings, :pos_approval)

    def initialize(pos_transaction:, exemption_type:, actor:, notes: nil, approver: nil, approver_pin: nil)
      @pos_transaction = pos_transaction
      @exemption_type = exemption_type
      @notes = notes
      @actor = actor
      @approver = approver
      @approver_pin = approver_pin
    end

    def call
      raise Error, "transaction is not open for editing" unless @pos_transaction.editable?
      raise Error, "exemption type is required" if @exemption_type.blank?

      store = @pos_transaction.store

      authorization = Pos::AuthorizeAction.call(
        store: store,
        requester: @actor,
        permission_key: "pos.tax.exempt",
        approver_permission_key: "pos.tax.exempt",
        action_type: "tax_exemption",
        reason: @notes,
        approver: @approver,
        approver_pin: @approver_pin,
        pos_transaction: @pos_transaction,
        pos_session: @pos_transaction.active_pos_session
      )
      return unauthorized_result(authorization) unless authorization.allowed?

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(@pos_transaction.id)
        raise Error, "transaction is not open for editing" unless transaction.editable?

        exemption = transaction.pos_tax_exemptions.first_or_create!(
          coverage: "whole_transaction",
          exemption_type: @exemption_type,
          notes: @notes,
          created_by_user: @actor
        )

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: store.organization,
          store: store,
          action: "pos_transaction.tax_exemption_applied",
          subject: exemption,
          metadata: {
            "exemption_type" => @exemption_type,
            "approved_by_user_id" => authorization.pos_approval&.approved_by_user_id
          }
        )

        recalculation = Pos::RecalculateTransaction.call(pos_transaction: transaction)

        Result.new(pos_tax_exemption: exemption, success?: true, error: nil,
                   warnings: recalculation.blockers + recalculation.warnings, pos_approval: authorization.pos_approval)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_tax_exemption: nil, success?: false, error: e.message, warnings: [], pos_approval: nil)
    end

    private

    def unauthorized_result(authorization)
      error = case authorization.status
      when :requires_approval then "tax exemption requires approval"
      else authorization.error || "tax exemption denied"
      end
      Result.new(pos_tax_exemption: nil, success?: false, error: error, warnings: [], pos_approval: nil)
    end
  end
end
