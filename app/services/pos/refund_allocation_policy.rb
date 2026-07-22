# frozen_string_literal: true

module Pos
  # Shared refund-destination policy for cash, card, and stored-value refunds.
  #
  # Linked returns must restore remaining original tenders in order:
  #   1. stored-value tenders
  #   2. eligible external (cash/card) tenders
  # Non-original destinations require exception approval while any remaining
  # original tender is still refundable.
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

      remaining = remaining_original_tenders(@pos_transaction)
      remaining_sv = remaining.select { |t| t.tender_type.tender_category == "stored_value" }

      if restoring_eligible_original?(remaining)
        if remaining_sv.any? && @original_pos_tender.tender_type.tender_category != "stored_value"
          return require_exception!(
            "bypass remaining original stored-value tender restoration (#{@destination})"
          )
        end
        return nil
      end

      return nil if remaining.empty?

      require_exception!(
        "bypass remaining original tender restoration (#{@destination}; " \
        "remaining: #{remaining.map(&:id).join(', ')})"
      )
    end

    def self.remaining_original_tenders(transaction)
      new(
        pos_transaction: transaction, actor: nil, destination: :cash, amount_cents: 0
      ).send(:remaining_original_tenders, transaction)
    end

    def self.remaining_original_sv_tenders(transaction)
      remaining_original_tenders(transaction).select { |t|
        t.tender_type.tender_category == "stored_value"
      }
    end

    private

    def restoring_eligible_original?(remaining)
      return false if @original_pos_tender.blank?

      match = remaining.find { |t| t.id == @original_pos_tender.id }
      raise Error, "original tender is not a remaining refundable tender on a linked sale" if match.blank?

      category = match.tender_type.tender_category
      case @destination
      when :original_stored_value
        raise Error, "original tender must be stored_value" unless category == "stored_value"
      when :cash
        raise Error, "original tender must be cash for a cash refund" unless category == "cash"
      when :card
        raise Error, "original tender must be card for a card refund" unless category == "card"
      when :new_stored_value
        return false
      end

      true
    end

    def require_exception!(reason)
      return @existing_exception_approval if @existing_exception_approval.present?

      auth = AuthorizeAction.call(
        store: @pos_transaction.store,
        requester: @actor,
        permission_key: "stored_value.tender.refund",
        action_type: "stored_value_refund_exception",
        reason: reason,
        approval_mode: :always,
        approver: @exception_approver,
        approver_pin: @exception_approver_pin,
        approver_permission_key: "stored_value.tender.refund",
        pos_transaction: @pos_transaction,
        requested_value: @amount_cents
      )
      return auth.pos_approval if auth.allowed? && auth.pos_approval

      raise Error,
            "restore remaining original tender(s) first " \
            "(#{remaining_original_tenders(@pos_transaction).map(&:id).join(', ')}) " \
            "or supply exception approval"
    end

    def remaining_original_tenders(transaction)
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
          tender_types: { tender_category: %w[stored_value cash card] }
        )
        .includes(:tender_type)
        .order(:id)
        .select { |tender| remaining_for_allocation(tender, transaction).positive? }
    end

    # Pending/authorized refunds on the current return already reduce
    # `remaining_refundable_cents`. Add them back so completion revalidation and
    # multi-tender allocation still see the originals being restored here.
    def remaining_for_allocation(original_tender, transaction)
      reserved_here = transaction.pos_tenders.unresolved
        .where(direction: "refunded", original_pos_tender_id: original_tender.id)
        .sum(:amount_cents)
      original_tender.remaining_refundable_cents + reserved_here
    end
  end
end
