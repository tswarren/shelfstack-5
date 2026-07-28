# frozen_string_literal: true

module Pos
  # Records a proposed refund plan by calling existing Add*RefundTender services
  # in order. Failures leave earlier successful tenders (cashier can remove);
  # callers should prefer accept when the plan is still the recommended SV-first set.
  class AcceptRefundPlan < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:success?, :error, :pos_tenders, :requires_approval?)

    def initialize(pos_transaction:, actor:, rows:, cash_tender_type:, stored_value_tender_type: nil)
      @pos_transaction = pos_transaction
      @actor = actor
      @rows = Array(rows)
      @cash_tender_type = cash_tender_type
      @stored_value_tender_type = stored_value_tender_type
    end

    def call
      raise Error, "plan has no rows" if @rows.empty?

      created = []
      @rows.each do |row|
        amount = row.fetch(:amount_cents).to_i
        next unless amount.positive?

        destination = row.fetch(:destination).to_sym
        original = row[:original_pos_tender]
        result = case destination
        when :original_stored_value
          raise Error, "stored-value tender type required" if @stored_value_tender_type.blank?

          AddStoredValueRefundTender.call(
            pos_transaction: @pos_transaction,
            tender_type: @stored_value_tender_type,
            amount_cents: amount,
            actor: @actor,
            original_pos_tender: original,
            account: original&.stored_value_account
          )
        when :cash
          raise Error, "cash tender type required" if @cash_tender_type.blank?

          AddCashRefundTender.call(
            pos_transaction: @pos_transaction,
            tender_type: @cash_tender_type,
            amount_cents: amount,
            actor: @actor,
            original_pos_tender: original
          )
        else
          raise Error, "unsupported plan destination #{destination}"
        end

        unless result.success?
          return Result.new(
            success?: false,
            error: result.error,
            pos_tenders: created,
            requires_approval?: result.respond_to?(:requires_approval?) && result.requires_approval?
          )
        end

        created << result.pos_tender
      end

      Result.new(success?: true, error: nil, pos_tenders: created, requires_approval?: false)
    rescue Error => e
      Result.new(success?: false, error: e.message, pos_tenders: created, requires_approval?: false)
    end
  end
end
