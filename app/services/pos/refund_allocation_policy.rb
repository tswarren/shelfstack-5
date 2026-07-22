# frozen_string_literal: true

module Pos
  # Validates the full refund allocation plan for a return transaction.
  #
  # Rules:
  # - Completed prior refunds reduce historical capacity.
  # - Unresolved refunds in *other* transactions are in-flight blockers (not
  #   completed restorations) and consume allocatable capacity.
  # - Unresolved refunds on *this* transaction are evaluated together.
  # - Remaining original stored-value tenders must be restored before cash,
  #   card, or new store-credit destinations, unless an exception approval
  #   is recorded on the bypassing tender.
  class RefundAllocationPolicy < ApplicationService
    Error = Class.new(StandardError)

    DESTINATIONS = %i[original_stored_value cash card new_stored_value].freeze
    EXCEPTION_APPROVER_PERMISSION = "pos.return.refund_exception.approve"

    PlanItem = Data.define(
      :destination,
      :amount_cents,
      :original_pos_tender,
      :existing_exception_approval,
      :tender_id
    )

    def initialize(
      pos_transaction:,
      actor:,
      proposed: nil,
      exception_approver: nil,
      exception_approver_pin: nil,
      # Legacy single-tender kwargs still accepted by callers; converted to proposed.
      destination: nil,
      amount_cents: nil,
      original_pos_tender: nil,
      existing_exception_approval: nil,
      excluding_tender_ids: []
    )
      @pos_transaction = pos_transaction
      @actor = actor
      @exception_approver = exception_approver
      @exception_approver_pin = exception_approver_pin
      @excluding_tender_ids = Array(excluding_tender_ids).compact
      @proposed = coerce_proposed(
        proposed,
        destination: destination,
        amount_cents: amount_cents,
        original_pos_tender: original_pos_tender,
        existing_exception_approval: existing_exception_approval
      )
    end

    # Returns the PosApproval for the proposed bypass tender when one is newly
    # authorized; otherwise nil. Raises when the plan is invalid.
    def call
      items = existing_plan_items(@pos_transaction)
      items << @proposed if @proposed
      validate_plan!(items)
    end

    def self.validate_plan!(pos_transaction:, actor:, refund_tenders: nil)
      new(pos_transaction: pos_transaction, actor: actor).tap do |policy|
        items = if refund_tenders
          refund_tenders.map { |t| policy.send(:plan_item_from_tender, t) }
        else
          policy.send(:existing_plan_items, pos_transaction)
        end
        policy.send(:validate_plan!, items)
      end
      nil
    end

    def self.remaining_original_tenders(transaction)
      new(pos_transaction: transaction, actor: nil).send(:allocatable_original_tenders, transaction)
    end

    def self.remaining_original_sv_tenders(transaction)
      remaining_original_tenders(transaction).select { |t|
        t.tender_type.tender_category == "stored_value"
      }
    end

    def self.destination_for(tender)
      case tender.tender_type.tender_category
      when "cash" then :cash
      when "card" then :card
      when "stored_value"
        tender.original_pos_tender_id.present? ? :original_stored_value : :new_stored_value
      end
    end

    private

    def coerce_proposed(proposed, destination:, amount_cents:, original_pos_tender:, existing_exception_approval:)
      return proposed if proposed.is_a?(PlanItem)
      if proposed.is_a?(Hash)
        return PlanItem.new(
          destination: proposed.fetch(:destination).to_sym,
          amount_cents: proposed.fetch(:amount_cents).to_i,
          original_pos_tender: proposed[:original_pos_tender],
          existing_exception_approval: proposed[:existing_exception_approval],
          tender_id: proposed[:tender_id]
        )
      end
      return nil if destination.nil?

      PlanItem.new(
        destination: destination.to_sym,
        amount_cents: amount_cents.to_i,
        original_pos_tender: original_pos_tender,
        existing_exception_approval: existing_exception_approval,
        tender_id: nil
      )
    end

    def existing_plan_items(transaction)
      scope = transaction.pos_tenders.unresolved.where(direction: "refunded").order(:id)
      scope = scope.where.not(id: @excluding_tender_ids) if @excluding_tender_ids.present?
      scope.map { |t| plan_item_from_tender(t) }
    end

    def plan_item_from_tender(tender)
      destination = self.class.destination_for(tender)
      raise Error, "unsupported refund tender category" if destination.nil?

      PlanItem.new(
        destination: destination,
        amount_cents: tender.amount_cents,
        original_pos_tender: tender.original_pos_tender,
        existing_exception_approval: tender.pos_approval,
        tender_id: tender.id
      )
    end

    def validate_plan!(items)
      raise Error, "unsupported refund destination" if items.any? { |i| !DESTINATIONS.include?(i.destination) }

      originals = linked_original_tenders(@pos_transaction)
      assert_capacity!(items, originals)
      assert_original_links!(items, originals)

      unrestored_sv = unrestored_after_plan(originals, items, category: "stored_value")
      unrestored_any = unrestored_after_plan(originals, items, category: nil)

      proposed_approval = nil
      items.each do |item|
        next unless requires_exception?(item, unrestored_sv, unrestored_any)

        if item.existing_exception_approval.present?
          next
        end

        if item.tender_id.present?
          raise Error,
                "restore remaining original tender(s) first " \
                "(#{unrestored_labels(originals, items)}) or supply exception approval"
        end

        proposed_approval = authorize_exception!(item)
      end

      proposed_approval
    end

    def assert_capacity!(items, originals)
      originals.each do |original|
        plan_sum = items.select { |i| i.original_pos_tender&.id == original.id }.sum(&:amount_cents)
        next if plan_sum.zero?

        completed = completed_refunded_cents(original)
        other = other_inflight_cents(original, @pos_transaction)
        capacity = original.amount_cents - completed - other
        if plan_sum > capacity
          if other.positive?
            raise Error,
                  "original tender #{original.id} has an in-flight refund in another transaction"
          end
          raise Error, "refund exceeds remaining refundable on original tender #{original.id} (#{capacity})"
        end
      end
    end

    def assert_original_links!(items, originals)
      original_ids = originals.map(&:id)
      items.each do |item|
        next if item.original_pos_tender.blank?

        unless original_ids.include?(item.original_pos_tender.id)
          raise Error, "original tender is not a remaining refundable tender on a linked sale"
        end

        category = item.original_pos_tender.tender_type.tender_category
        case item.destination
        when :original_stored_value
          raise Error, "original tender must be stored_value" unless category == "stored_value"
        when :cash
          raise Error, "original tender must be cash for a cash refund" unless category == "cash"
        when :card
          raise Error, "original tender must be card for a card refund" unless category == "card"
        when :new_stored_value
          raise Error, "new stored-value refund cannot link an original tender"
        end
      end
    end

    def requires_exception?(item, unrestored_sv, unrestored_any)
      if item.destination == :original_stored_value && item.original_pos_tender.present?
        return false
      end

      if item.original_pos_tender.present? && %i[cash card].include?(item.destination)
        return unrestored_sv.any?
      end

      unrestored_any.any?
    end

    def unrestored_after_plan(originals, items, category:)
      scoped = if category
        originals.select { |t| t.tender_type.tender_category == category }
      else
        originals
      end

      scoped.select { |original|
        plan_toward = items.select { |i| i.original_pos_tender&.id == original.id }.sum(&:amount_cents)
        remaining = original.amount_cents - completed_refunded_cents(original) - plan_toward
        remaining.positive?
      }
    end

    def unrestored_labels(originals, items)
      unrestored_after_plan(originals, items, category: nil).map(&:id).join(", ")
    end

    def authorize_exception!(item)
      auth = AuthorizeAction.call(
        store: @pos_transaction.store,
        requester: @actor,
        permission_key: requester_permission_for(item.destination),
        action_type: "stored_value_refund_exception",
        reason: "bypass remaining original tender restoration (#{item.destination})",
        approval_mode: :always,
        approver: @exception_approver,
        approver_pin: @exception_approver_pin,
        approver_permission_key: EXCEPTION_APPROVER_PERMISSION,
        pos_transaction: @pos_transaction,
        requested_value: item.amount_cents
      )
      return auth.pos_approval if auth.allowed? && auth.pos_approval

      raise Error,
            "restore remaining original tender(s) first or supply exception approval " \
            "(#{auth.error || 'requires approval'})"
    end

    def requester_permission_for(destination)
      case destination
      when :cash then "pos.tender.cash"
      when :card then "pos.tender.card_standalone"
      when :original_stored_value, :new_stored_value then "stored_value.tender.refund"
      else
        raise Error, "unsupported refund destination: #{destination}"
      end
    end

    def linked_original_tenders(transaction)
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
        .to_a
    end

    def allocatable_original_tenders(transaction)
      linked_original_tenders(transaction).select { |tender|
        allocatable_cents(tender, transaction).positive?
      }
    end

    def allocatable_cents(original, transaction)
      plan_scope = transaction.pos_tenders.unresolved
        .where(direction: "refunded", original_pos_tender_id: original.id)
      plan_scope = plan_scope.where.not(id: @excluding_tender_ids) if @excluding_tender_ids.present?
      plan_toward = plan_scope.sum(:amount_cents)
      original.amount_cents -
        completed_refunded_cents(original) -
        other_inflight_cents(original, transaction) -
        plan_toward
    end

    def completed_refunded_cents(original)
      original.refund_tenders.where(status: "completed").sum(:amount_cents)
    end

    def other_inflight_cents(original, transaction)
      original.refund_tenders
        .where(status: %w[pending authorized])
        .where.not(pos_transaction_id: transaction.id)
        .sum(:amount_cents)
    end
  end
end
