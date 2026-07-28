# frozen_string_literal: true

module Pos
  # Cashier-facing Tender UI state derived from persisted facts + query params.
  # Presentational only — does not mutate the transaction (POS-UI-035).
  #
  # Settlement vs readiness are separate:
  #   settled?     = balance_due_cents.zero?
  #   completable? = settled? && completion readiness passes
  class TenderPresentation
    METHODS = %w[cash card stored_value].freeze

    Result = Data.define(
      :direction,
      :refund_mode?,
      :settled?,
      :completable?,
      :available_methods,
      :selected_method,
      :selected_card_type,
      :method_labels,
      :remaining_cents,
      :recorded_tenders,
      :selected_tender,
      :return_safe?,
      :forced_tender?,
      :active_form_id,
      :cta_label,
      :cta_submits_form?,
      :card_types,
      :cash_types,
      :stored_value_types,
      :refundable_original_tenders
    )

    def self.for(**kwargs)
      new(**kwargs).call
    end

    def initialize(pos_transaction:, balance_due_cents:, tender_types:, pos_tenders:,
                   refundable_original_tenders: [], tender_method_param: nil,
                   tender_type_id_param: nil, selected_tender_id: nil, actor:, store:,
                   ready_for_completion: false)
      @pos_transaction = pos_transaction
      @balance_due_cents = balance_due_cents.to_i
      @tender_types = tender_types
      @pos_tenders = Array(pos_tenders)
      @refundable_original_tenders = Array(refundable_original_tenders)
      @tender_method_param = tender_method_param.to_s.presence
      @tender_type_id_param = tender_type_id_param.presence&.to_i
      @selected_tender_id = selected_tender_id.presence&.to_i
      @actor = actor
      @store = store
      @ready_for_completion = ready_for_completion
    end

    def call
      Result.new(
        direction: refund_mode? ? "refund" : "payment",
        refund_mode?: refund_mode?,
        settled?: settled?,
        completable?: completable?,
        available_methods: available_methods,
        selected_method: selected_method,
        selected_card_type: selected_card_type,
        method_labels: method_labels,
        remaining_cents: remaining_cents,
        recorded_tenders: @pos_tenders,
        selected_tender: selected_tender,
        return_safe?: return_safe?,
        forced_tender?: forced_tender?,
        active_form_id: "active_tender_form",
        cta_label: cta_label,
        cta_submits_form?: cta_submits_form?,
        card_types: types_for("card"),
        cash_types: types_for("cash"),
        stored_value_types: types_for("stored_value"),
        refundable_original_tenders: @refundable_original_tenders
      )
    end

    private

    def refund_mode?
      @balance_due_cents.negative?
    end

    def settled?
      @balance_due_cents.zero?
    end

    def completable?
      settled? && @ready_for_completion
    end

    def remaining_cents
      @balance_due_cents.abs
    end

    def forced_tender?
      @pos_transaction.open? && @pos_transaction.unresolved_tenders?
    end

    def return_safe?
      @pos_transaction.open? && !forced_tender? && !@pos_transaction.void_required_tenders?
    end

    def available_methods
      return [] if settled?

      METHODS.select { |method| method_permitted?(method) }
    end

    def method_permitted?(method)
      case method
      when "cash"
        can?("pos.tender.cash") && types_for("cash").any?
      when "card"
        can?("pos.tender.card_standalone") && types_for("card").any?
      when "stored_value"
        if refund_mode?
          can?("stored_value.tender.refund") && types_for("stored_value").any?
        else
          can?("stored_value.tender.redeem") && types_for("stored_value").any? && @balance_due_cents.positive?
        end
      else
        false
      end
    end

    def selected_method
      return nil if settled? || available_methods.empty?
      return @tender_method_param if available_methods.include?(@tender_method_param)

      default_method
    end

    def selected_card_type
      return nil unless selected_method == "card"

      types = types_for("card")
      return nil if types.empty?

      types.find { |type| type.id == @tender_type_id_param } || types.first
    end

    def default_method
      if refund_mode?
        %w[stored_value card cash].find { |method| available_methods.include?(method) }
      else
        %w[cash card stored_value].find { |method| available_methods.include?(method) }
      end
    end

    def method_labels
      available_methods.index_with { |method| label_for(method) }
    end

    def label_for(method)
      noun = case method
      when "cash" then "Cash"
      when "card" then "Card"
      when "stored_value" then "Stored Value"
      else method.humanize
      end
      "#{noun} #{refund_mode? ? "refund" : "payment"}"
    end

    def selected_tender
      return nil if @selected_tender_id.blank?

      @pos_tenders.find { |tender| tender.id == @selected_tender_id }
    end

    def cta_submits_form?
      !settled? && selected_method.present? && @balance_due_cents != 0
    end

    def cta_label
      return "Complete transaction" if completable?
      return nil if settled?
      return nil unless cta_submits_form?

      money = format("$%.2f", remaining_cents / 100.0)
      refund_mode? ? "Add refund #{money}" : "Add tender #{money}"
    end

    def types_for(category)
      @tender_types.select { |type| type.tender_category == category }
    end

    def can?(permission_key)
      Authorization::EvaluatePermission.call(
        user: @actor, store: @store, permission_key: permission_key
      ) == :allow
    end
  end
end
