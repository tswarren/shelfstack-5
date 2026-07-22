# frozen_string_literal: true

module Pos
  # Shared refund-destination policy for cash, card, and stored-value refunds.
  # Linked returns must restore remaining original stored-value tenders before
  # other destinations, unless an exception approval is recorded.
  class RefundAllocationPolicy < ApplicationService
    Error = Class.new(StandardError)

    DESTINATIONS = %i[original_stored_value cash card new_stored_value].freeze

    def initialize(
      pos_transaction:,
      actor:,
      destination:,
      amount_cents:,
      original_pos_tender: nil,
      exception_approver: nil,
      exception_approver_pin: nil,
      existing_exception_approval: nil
    )
      @pos_transaction = pos_transaction
      @actor = actor
      @destination = destination.to_sym
      @amount_cents = amount_cents.to_i
      @original_pos_tender = original_pos_tender
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
      @existing_exception_approval = existing_exception_approval
    end

    def call
      raise Error, "unsupported refund destination: #{@destination}" unless DESTINATIONS.include?(@destination)

      remaining = remaining_original_sv_tenders(@pos_transaction)
      return nil if remaining.empty?

      if @destination == :original_stored_value
        raise Error, "original stored-value tender is required" if @original_pos_tender.blank?
        unless remaining.any? { |t| t.id == @original_pos_tender.id }
          raise Error, "original tender is not a remaining refundable stored-value tender on a linked sale"
        end
        return nil
      end

      return @existing_exception_approval if @existing_exception_approval.present?

      auth = AuthorizeAction.call(
        store: @pos_transaction.store,
        requester: @actor,
        permission_key: "stored_value.tender.refund",
        action_type: "stored_value_refund_exception",
        reason: "bypass original stored-value tender restoration (#{@destination})",
        approval_mode: :always,
        approver: @exception_approver,
        approver_pin: @exception_approver_pin,
        approver_permission_key: "stored_value.tender.refund",
        pos_transaction: @pos_transaction,
        requested_value: @amount_cents
      )
      return auth.pos_approval if auth.allowed? && auth.pos_approval

      raise Error,
            "restore remaining original stored-value tender(s) first " \
            "(#{remaining.map(&:id).join(', ')}) or supply exception approval"
    end

    def self.remaining_original_sv_tenders(transaction)
      new(
        pos_transaction: transaction, actor: nil, destination: :cash, amount_cents: 0
      ).send(:remaining_original_sv_tenders, transaction)
    end

    private

    def remaining_original_sv_tenders(transaction)
      linked_sale_ids = transaction.pos_line_items.pending.returns
        .where.not(original_pos_line_item_id: nil)
        .includes(original_pos_line_item: :pos_transaction)
        .map { |line| line.original_pos_line_item.pos_transaction_id }
        .uniq

      return [] if linked_sale_ids.empty?

      PosTender
        .joins(:tender_type)
        .where(
          pos_transaction_id: linked_sale_ids,
          direction: "received",
          status: "completed",
          store_id: transaction.store_id,
          tender_types: { tender_category: "stored_value" }
        )
        .order(:id)
        .select { |tender| tender.remaining_refundable_cents.positive? }
    end
  end
end
