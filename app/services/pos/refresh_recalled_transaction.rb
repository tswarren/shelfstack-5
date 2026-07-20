# frozen_string_literal: true

module Pos
  # On recall, refresh current catalog price/classification and surface eligibility
  # blockers for pending sale product lines (domain "Suspended Transactions").
  # Preserves approved price and tax-category overrides. Linked returns and open-ring
  # lines keep their historical commercial values.
  class RefreshRecalledTransaction < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:pos_transaction, :success?, :error, :warnings, :blockers, :changes)

    Change = Data.define(:pos_line_item_id, :field, :from, :to)

    def initialize(pos_transaction:)
      @pos_transaction = pos_transaction
    end

    def call
      transaction = @pos_transaction
      raise Error, "transaction must be open" unless transaction.open?

      warnings = []
      blockers = []
      changes = []

      ActiveRecord::Base.transaction do
        transaction = PosTransaction.lock.find(transaction.id)
        raise Error, "transaction must be open" unless transaction.open?

        transaction.pos_line_items.pending.sales.where(line_kind: "product").order(:position, :id).lock.each do |line|
          variant = line.product_variant
          if variant.blank?
            blockers << "line #{line.id} is missing its product variant"
            next
          end

          eligibility = Catalog::SaleEligibility.call(variant: variant, store: transaction.store)
          eligibility.blockers.each do |code|
            blockers << "line #{line.id}: #{code}"
          end
          warnings.concat(eligibility.warnings)

          attrs = {}
          unless line.price_overridden_at.present?
            new_price = resolved_unit_price_cents(line, variant)
            if new_price.present? && new_price != line.unit_price_cents
              changes << Change.new(pos_line_item_id: line.id, field: "unit_price_cents",
                                    from: line.unit_price_cents, to: new_price)
              attrs[:unit_price_cents] = new_price
            end
          end

          department = classification_for(variant).department
          if department && department.id != line.department_id
            changes << Change.new(pos_line_item_id: line.id, field: "department_id",
                                  from: line.department_id, to: department.id)
            attrs[:department_id] = department.id
          end

          unless line.tax_category_overridden_at.present?
            tax_category = classification_for(variant).tax_category
            if tax_category&.id != line.tax_category_id
              changes << Change.new(pos_line_item_id: line.id, field: "tax_category_id",
                                    from: line.tax_category_id, to: tax_category&.id)
              attrs[:tax_category_id] = tax_category&.id
            end
          end

          line.update!(attrs) if attrs.any?
        end

        recalc = Pos::RecalculateTransaction.call(pos_transaction: transaction)
        blockers.concat(recalc.blockers)
        warnings.concat(recalc.warnings)

        Result.new(
          pos_transaction: transaction,
          success?: true,
          error: nil,
          warnings: warnings.uniq,
          blockers: blockers.uniq,
          changes: changes
        )
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_transaction: nil, success?: false, error: e.message, warnings: [], blockers: [], changes: [])
    end

    private

    def resolved_unit_price_cents(line, variant)
      if line.inventory_unit_id.present?
        line.inventory_unit.unit_price_cents || variant.regular_price_cents
      else
        variant.regular_price_cents
      end
    end

    def classification_for(variant)
      Catalog::ResolveClassification.call(product: variant.product, variant: variant)
    end
  end
end
