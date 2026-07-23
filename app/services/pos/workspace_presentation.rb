# frozen_string_literal: true

module Pos
  # Cashier-facing presentation state derived from records + URL params.
  # Not a persisted transaction status.
  class WorkspacePresentation
    STATES = %w[ready receipt recovery tender transaction].freeze

    Result = Data.define(
      :state,
      :label,
      :primary_action,
      :primary_label,
      :primary_amount_cents,
      :ready_for_tender,
      :ready_for_completion,
      :forced_tender
    )

    def self.for(**kwargs)
      new(**kwargs).call
    end

    def initialize(pos_transaction: nil, presentation_param: nil, readiness: nil,
                   net_total_cents: 0, balance_due_cents: 0, open_session: nil)
      @pos_transaction = pos_transaction
      @presentation_param = presentation_param.to_s.presence
      @readiness = readiness
      @net_total_cents = net_total_cents.to_i
      @balance_due_cents = balance_due_cents.to_i
      @open_session = open_session
    end

    def call
      state = derive_state
      Result.new(
        state: state,
        label: state.to_s.humanize,
        primary_action: primary_action_for(state),
        primary_label: primary_label_for(state),
        primary_amount_cents: primary_amount_for(state),
        ready_for_tender: ready_for_tender?,
        ready_for_completion: ready_for_completion?,
        forced_tender: forced_tender?
      )
    end

    private

    def derive_state
      return "ready" if @pos_transaction.blank?
      return "receipt" if @pos_transaction.completed?
      return "recovery" if @pos_transaction.open? && @pos_transaction.void_required_tenders?
      return "tender" if @pos_transaction.open? && forced_tender?
      return "tender" if @pos_transaction.open? && @presentation_param == "tender"
      return "transaction" if @pos_transaction.open? || @pos_transaction.suspended?

      "transaction"
    end

    def forced_tender?
      @pos_transaction&.open? && @pos_transaction.unresolved_tenders?
    end

    def ready_for_tender?
      return false if @pos_transaction.blank? || !@pos_transaction.open?
      return false if @pos_transaction.void_required_tenders?
      return @readiness.ready_for_tender? if @readiness

      @pos_transaction.pos_line_items.pending.exists?
    end

    def ready_for_completion?
      return false unless @readiness

      @readiness.ready_for_completion?
    end

    def primary_action_for(state)
      case state
      when "receipt" then :next_transaction
      when "recovery" then :resolve_recovery
      when "tender"
        return :complete if @balance_due_cents.zero? && ready_for_completion?

        @net_total_cents.negative? || @balance_due_cents.negative? ? :add_refund : :add_payment
      when "transaction"
        return :resolve_blockers if @readiness && @readiness.blockers.any?
        return :issue_refund if @net_total_cents.negative?
        return :tender if ready_for_tender?

        :scan
      else
        :scan
      end
    end

    def primary_label_for(state)
      action = primary_action_for(state)
      amount = primary_amount_for(state)
      money = format_cents(amount)

      case action
      when :next_transaction then "Next transaction"
      when :resolve_recovery then "Resolve card void"
      when :complete then "Complete transaction"
      when :add_payment then "Add payment #{money}"
      when :add_refund then "Add refund #{money}"
      when :issue_refund then "Issue refund #{money}"
      when :tender then "Tender #{money}"
      when :resolve_blockers
        count = @readiness&.blockers&.size.to_i
        "Resolve #{count} #{'blocker'.pluralize(count)}"
      else
        "Continue scanning"
      end
    end

    def primary_amount_for(state)
      case primary_action_for(state)
      when :add_payment, :add_refund then @balance_due_cents.abs
      when :tender, :issue_refund then @net_total_cents.abs
      else 0
      end
    end

    def format_cents(cents)
      format("$%.2f", cents.to_i.abs / 100.0)
    end
  end
end
