# frozen_string_literal: true

module Classification
  class CreateDepartment < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      code department_number name parent_department_id postable
      inventory_asset_gl_account_code sales_revenue_gl_account_code
      sales_returns_gl_account_code sales_discounts_gl_account_code cogs_gl_account_code
      vendor_returns_gl_account_code inventory_shrinkage_gl_account_code
      inventory_write_down_gl_account_code inventory_adjustment_gl_account_code
      freight_in_gl_account_code default_tax_category_id maximum_merchandise_discount
      default_return_policy_id default_cost_estimation_margin_bps active
    ].freeze

    def initialize(department:, actor:, organization:)
      @department = department
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @department.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "department.created",
          subject: @department,
          metadata: {
            "code" => @department.code,
            "after" => Administration::ChangeMetadata.snapshot(@department, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
