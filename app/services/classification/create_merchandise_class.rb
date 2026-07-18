# frozen_string_literal: true

module Classification
  class CreateMerchandiseClass < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      code name level description position parent_id default_department_id
      default_used_department_id default_inventory_tracking_mode default_discountability
      default_returnability default_tax_category_id shelving_guidance active
    ].freeze

    def initialize(merchandise_class:, actor:, organization:)
      @merchandise_class = merchandise_class
      @actor = actor
      @organization = organization
    end

    def call
      ActiveRecord::Base.transaction do
        @merchandise_class.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "merchandise_class.created",
          subject: @merchandise_class,
          metadata: {
            "code" => @merchandise_class.code,
            "after" => Administration::ChangeMetadata.snapshot(@merchandise_class, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
