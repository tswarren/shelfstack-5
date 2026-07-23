# frozen_string_literal: true

module Pos
  # Side-effect-free readiness snapshot for cashier UI (GET-safe).
  # Does not lock, recalculate, reassign residuals, or write rows.
  # Completion still uses ValidateCompletionReadiness under locks.
  class ProjectCompletionReadiness < ApplicationService
    Issue = Data.define(:severity, :code, :message, :line_id, :target)
    Result = Data.define(
      :issues,
      :net_total_cents,
      :tendered_total_cents,
      :remaining_cents,
      :ready_for_tender,
      :ready_for_completion
    ) do
      def blockers = issues.select { |i| i.severity == :blocker }
      def warnings = issues.select { |i| i.severity == :warning }
      def approvals = issues.select { |i| i.severity == :approval }
      def infos = issues.select { |i| i.severity == :info }
      def ready_for_tender? = ready_for_tender
      def ready_for_completion? = ready_for_completion
    end

    def initialize(pos_transaction:, discount_cents_by_id: nil, tax_cents_by_id: nil)
      @pos_transaction = pos_transaction
      @discount_cents_by_id = discount_cents_by_id
      @tax_cents_by_id = tax_cents_by_id
    end

    def call
      issues = []
      lines = @pos_transaction.pos_line_items.pending.order(:position, :id).to_a
      tenders = @pos_transaction.pos_tenders.where(status: PosTender::UNRESOLVED_STATUSES).to_a +
        @pos_transaction.pos_tenders.where(status: "completed").to_a

      if @pos_transaction.void_required_tenders?
        issues << issue(:blocker, "card_void_required",
                        "Confirm external voids for void-required card tenders before continuing.")
      end

      if lines.empty?
        issues << issue(:blocker, "no_lines", "Add at least one line before tendering or completing.")
      end

      lines.each { |line| issues.concat(line_issues(line)) }

      net = snapshot_net_cents(lines)
      tendered = tendered_total_cents
      remaining = net - tendered

      if remaining != 0 && tenders.any?
        issues << issue(:blocker, "tenders_unsettled",
                        "Tenders do not settle the transaction net (remaining #{remaining} cents).")
      end

      if remaining != 0 && tenders.empty? && lines.any?
        # Informational until cashier enters tender — not a Transaction-state blocker
        issues << issue(:info, "balance_due",
                        remaining.positive? ? "Amount due before completion." : "Refund due before completion.")
      end

      blockers = issues.select { |i| i.severity == :blocker || i.severity == :approval }
      # Balance/settlement issues belong to Tender/Complete, not blocking entry to tender.
      tender_entry_blockers = blockers.reject { |i| %w[tenders_unsettled balance_due].include?(i.code) }
      ready_for_tender = lines.any? && tender_entry_blockers.empty?
      ready_for_completion = ready_for_tender && remaining.zero? && blockers.empty?

      Result.new(
        issues: issues,
        net_total_cents: net,
        tendered_total_cents: tendered,
        remaining_cents: remaining,
        ready_for_tender: ready_for_tender,
        ready_for_completion: ready_for_completion
      )
    end

    private

    def line_issues(line)
      list = []
      if line.line_kind != "stored_value"
        department = line.department
        if department.nil? || !department.active? || !department.postable?
          list << issue(:blocker, "missing_department",
                        "Line needs an active postable department.", line_id: line.id, target: "department")
        end
      end

      if line.sale? && line.line_kind == "product"
        if line.product_variant.blank?
          list << issue(:blocker, "missing_variant", "Line is missing its product variant.",
                        line_id: line.id, target: "variant")
        end
        if line.unit_price_cents.nil?
          list << issue(:blocker, "missing_price", "Line has no selling price.",
                        line_id: line.id, target: "price")
        end
        if line.product_variant.present?
          eligibility = Catalog::SaleEligibility.call(variant: line.product_variant, store: @pos_transaction.store)
          eligibility.blockers.each do |blocker|
            list << issue(:blocker, "sale_ineligible", "Not eligible for sale: #{blocker}",
                          line_id: line.id, target: "eligibility")
          end
          eligibility.warnings.each do |warning|
            list << issue(:warning, "sale_warning", warning.to_s, line_id: line.id, target: "eligibility")
          end
        end
        if line.product_variant&.inventory_tracking_mode == "individual" && line.inventory_unit_id.blank?
          list << issue(:blocker, "exact_unit_required", "Exact inventory unit required.",
                        line_id: line.id, target: "unit")
        end
      end

      list
    end

    def snapshot_net_cents(lines)
      lines.sum do |line|
        sign = line.return? ? -1 : 1
        discount = if @discount_cents_by_id
          @discount_cents_by_id[line.id].to_i
        else
          line.discount_amount_cents.to_i
        end
        tax = if @tax_cents_by_id
          @tax_cents_by_id[line.id].to_i
        else
          line.tax_amount_cents.to_i
        end
        sign * (line.extended_price_cents.to_i - discount + tax)
      end
    end

    def tendered_total_cents
      received = @pos_transaction.pos_tenders.where(status: %w[pending authorized completed], direction: "received")
        .sum(:amount_cents)
      refunded = @pos_transaction.pos_tenders.where(status: %w[pending authorized completed], direction: "refunded")
        .sum(:amount_cents)
      received - refunded
    end

    def issue(severity, code, message, line_id: nil, target: nil)
      Issue.new(severity: severity, code: code, message: message, line_id: line_id, target: target)
    end
  end
end
