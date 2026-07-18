# frozen_string_literal: true

require "csv"

module Classification
  module Import
    # Routine seed import is create-or-descriptive-update only.
    # Operational/accounting fields are set on create and preserved on re-run.
    # Canonical operational refresh belongs in an explicit audited sync task (future).
    class ReferenceData < ApplicationService
      include Helpers

      EXPORTS_ROOT = Rails.root.join("docs/exports")

      def initialize(organization:)
        @organization = organization
      end

      def call
        %w[
          tax_categories.csv return_policies.csv return_reasons.csv discount_reasons.csv
          departments.csv merchandise_classes.csv product_formats.csv product_conditions.csv
          inventory_adjustment_reasons.csv tender_types.csv cash_movement_types.csv
        ].each { |filename| load_csv(filename) }

        ActiveRecord::Base.transaction do
          import_tax_categories!
          import_return_policies!
          import_return_reasons!
          import_discount_reasons!
          import_departments!
          import_merchandise_classes!
          import_product_formats!
          import_product_conditions!
          import_inventory_adjustment_reasons!
          import_tender_types!
          import_cash_movement_types!
        end
        true
      end

      private

      def import_tax_categories!
        load_csv("tax_categories.csv").each do |row|
          record = @organization.tax_categories.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_return_policies!
        load_csv("return_policies.csv").each do |row|
          record = @organization.return_policies.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          if record.new_record?
            record.final_sale = truthy?(row["final_sale"])
            record.return_window_days = parse_integer(row["return_window_days"])
          end
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_return_reasons!
        load_csv("return_reasons.csv").each do |row|
          record = @organization.return_reasons.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          if record.new_record?
            record.default_return_disposition = row["default_return_disposition"].presence
          end
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_discount_reasons!
        load_csv("discount_reasons.csv").each do |row|
          record = @organization.discount_reasons.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          if record.new_record?
            record.default_calculation_method = row["default_calculation_method"].presence || "percentage"
            record.default_rate_bps = parse_integer(row["default_rate_bps"])
            record.default_amount_cents = parse_integer(row["default_amount_cents"])
            record.maximum_rate_bps = parse_integer(row["maximum_rate_bps"])
            record.requires_approval = truthy?(row["requires_approval"])
            record.resulting_return_policy = resolve_return_policy(row["resulting_return_policy_code"])
          end
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_departments!
        rows = load_csv("departments.csv")
        pending_parents = []

        rows.each do |row|
          record = @organization.departments.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          if record.new_record?
            record.department_number = row["department_number"].to_s
            record.postable = truthy?(row["postable"])
            assign_gl_account_codes(record, row)
            record.default_tax_category = resolve_tax_category(row["tax_category_code"])
          end
          assign_active_preserving_deactivation(record, row["active"])
          record.save!

          parent_number = row["parent_department_number"]
          if record.previously_new_record? && !blank_value?(parent_number)
            pending_parents << [ record, parent_number ]
          end
        end

        pending_parents.each do |record, parent_number|
          parent = find_department_by_number!(parent_number)
          record.update!(parent_department: parent)
        end
      end

      def import_merchandise_classes!
        rows = load_csv("merchandise_classes.csv")

        %w[primary secondary minor].each do |level|
          rows.select { |row| row["level"] == level }.each do |row|
            record = @organization.merchandise_classes.find_or_initialize_by(code: row["code"])
            record.name = row["name"]
            if record.new_record?
              record.level = row["level"]
              record.description = row["description"].presence
              record.position = parse_integer(row["position"])
              record.default_department = resolve_postable_department!(
                row["default_department_number"],
                context: "default department for #{row["code"]}"
              )
              used_number = row["default_used_department_number"]
              record.default_used_department = if blank_value?(used_number)
                nil
              else
                resolve_postable_department!(
                  used_number,
                  context: "default used department for #{row["code"]}"
                )
              end
              record.default_inventory_tracking_mode = row["default_inventory_tracking_mode"].presence
              record.default_discountability = row["default_discountability"].presence
              record.default_returnability = row["default_returnability"].presence
              record.default_tax_category = resolve_tax_category(row["default_tax_category_code"])
              record.shelving_guidance = row["shelving_guidance"].presence

              parent_code = row["parent_code"]
              unless blank_value?(parent_code)
                record.parent = @organization.merchandise_classes.find_by!(code: parent_code)
              end
            end
            assign_active_preserving_deactivation(record, row["active"])
            record.save!
          end
        end
      end

      def import_product_formats!
        load_csv("product_formats.csv").each do |row|
          record = @organization.product_formats.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          if record.new_record?
            record.short_code = row["short_code"]
            record.format_family = row["format_family"]
            record.default_inventory_tracking_mode = row["default_inventory_tracking_mode"]
          end
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_product_conditions!
        load_csv("product_conditions.csv").each do |row|
          record = @organization.product_conditions.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          if record.new_record?
            record.description = row["description"].presence
            record.position = parse_integer(row["position"]) || 0
          else
            record.description = row["description"].presence if row.key?("description")
          end
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_inventory_adjustment_reasons!
        load_csv("inventory_adjustment_reasons.csv").each do |row|
          record = @organization.inventory_adjustment_reasons.find_or_initialize_by(
            adjustment_kind: row["adjustment_kind"],
            code: row["code"]
          )
          record.name = row["name"]
          record.description = row["description"].presence
          record.requires_note = truthy?(row["requires_note"])
          record.position = parse_integer(row["position"]) || 0
          assign_active_preserving_deactivation(record, row.fetch("active", "TRUE"))
          record.save!
        end
      end

      def import_tender_types!
        load_csv("tender_types.csv").each do |row|
          record = @organization.tender_types.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          if record.new_record?
            record.tender_category = row["tender_category"]
            record.shortcut = row["shortcut"].presence
            record.payment_enabled = truthy?(row.fetch("payment_enabled", "TRUE"))
            record.refund_enabled = truthy?(row.fetch("refund_enabled", "TRUE"))
            record.allows_over_tender = truthy?(row.fetch("allows_over_tender", "FALSE"))
            record.provides_change = truthy?(row.fetch("provides_change", "FALSE"))
            record.reference_1_requirement = row["reference_1_requirement"].presence || "none"
            record.reference_1_label = row["reference_1_label"].presence
            record.reference_2_requirement = row["reference_2_requirement"].presence || "none"
            record.reference_2_label = row["reference_2_label"].presence
          end
          assign_active_preserving_deactivation(record, row.fetch("active", "TRUE"))
          record.save!
        end
      end

      def import_cash_movement_types!
        load_csv("cash_movement_types.csv").each do |row|
          record = @organization.cash_movement_types.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          if record.new_record?
            record.direction = row["direction"]
            record.requires_approval = truthy?(row.fetch("requires_approval", "TRUE"))
            record.requires_reference = truthy?(row.fetch("requires_reference", "TRUE"))
          end
          assign_active_preserving_deactivation(record, row.fetch("active", "TRUE"))
          record.save!
        end
      end

      def assign_gl_account_codes(record, row)
        %w[
          inventory_asset sales_revenue sales_returns sales_discounts cogs vendor_returns
          inventory_shrinkage inventory_write_down inventory_adjustment freight_in
        ].each do |suffix|
          column = "#{suffix}_gl_account_code"
          record.public_send(:"#{column}=", row[column].presence)
        end
      end

      def resolve_tax_category(code)
        return nil if blank_value?(code)

        @organization.tax_categories.find_by!(code: code)
      end

      def resolve_return_policy(code)
        return nil if blank_value?(code)

        @organization.return_policies.find_by!(code: code)
      end

      def find_department_by_number!(number)
        @organization.departments.find_by!(department_number: number.to_s)
      end

      def resolve_postable_department!(number, context:)
        department = find_department_by_number!(number)
        unless department.postable?
          raise ArgumentError, "#{context} references non-postable department #{number}"
        end

        department
      end

      def parse_integer(value)
        return nil if blank_value?(value)

        Integer(value)
      end
    end
  end
end
