# frozen_string_literal: true

require "csv"

module Classification
  module Import
    class ReferenceData < ApplicationService
      include Helpers

      EXPORTS_ROOT = Rails.root.join("docs/exports")

      def initialize(organization:)
        @organization = organization
      end

      def call
        # Preflight: ensure every export parses before mutating.
        %w[
          tax_categories.csv return_policies.csv return_reasons.csv discount_reasons.csv
          departments.csv merchandise_classes.csv product_formats.csv product_conditions.csv
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
          record.final_sale = truthy?(row["final_sale"])
          record.return_window_days = parse_integer(row["return_window_days"])
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_return_reasons!
        load_csv("return_reasons.csv").each do |row|
          record = @organization.return_reasons.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          record.default_return_disposition = row["default_return_disposition"].presence
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_discount_reasons!
        load_csv("discount_reasons.csv").each do |row|
          record = @organization.discount_reasons.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          record.default_calculation_method = row["default_calculation_method"].presence || "percentage"
          record.default_rate_bps = parse_integer(row["default_rate_bps"])
          record.default_amount_cents = parse_integer(row["default_amount_cents"])
          record.maximum_rate_bps = parse_integer(row["maximum_rate_bps"])
          record.requires_approval = truthy?(row["requires_approval"])
          record.resulting_return_policy = resolve_return_policy(row["resulting_return_policy_code"])
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_departments!
        rows = load_csv("departments.csv")
        pending_parents = []

        rows.each do |row|
          record = @organization.departments.find_or_initialize_by(code: row["code"])
          record.department_number = row["department_number"].to_s if record.new_record?
          record.name = row["name"]
          record.postable = truthy?(row["postable"])
          assign_gl_account_codes(record, row)
          record.default_tax_category = resolve_tax_category(row["tax_category_code"])
          assign_active_preserving_deactivation(record, row["active"])
          record.save!

          parent_number = row["parent_department_number"]
          pending_parents << [ record, parent_number ] unless blank_value?(parent_number)
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
            assign_active_preserving_deactivation(record, row["active"])

            parent_code = row["parent_code"]
            unless blank_value?(parent_code)
              record.parent = @organization.merchandise_classes.find_by!(code: parent_code)
            end

            record.save!
          end
        end
      end

      def import_product_formats!
        load_csv("product_formats.csv").each do |row|
          record = @organization.product_formats.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          record.short_code = row["short_code"]
          record.format_family = row["format_family"]
          record.default_inventory_tracking_mode = row["default_inventory_tracking_mode"]
          assign_active_preserving_deactivation(record, row["active"])
          record.save!
        end
      end

      def import_product_conditions!
        load_csv("product_conditions.csv").each do |row|
          record = @organization.product_conditions.find_or_initialize_by(code: row["code"])
          record.name = row["name"]
          record.description = row["description"].presence
          record.position = parse_integer(row["position"]) || 0
          assign_active_preserving_deactivation(record, row["active"])
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
