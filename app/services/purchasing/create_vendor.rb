# frozen_string_literal: true

module Purchasing
  class CreateVendor < ApplicationService
    TRACKED_ATTRIBUTES = %w[
      code name legal_name active ordering_contact ordering_email phone
      account_reference default_supplier_discount_bps notes
    ].freeze

    def initialize(vendor:, actor:, organization:, store: nil)
      @vendor = vendor
      @actor = actor
      @organization = organization
      @store = store
    end

    def call
      if @store.present? &&
          Authorization::EvaluatePermission.call(user: @actor, store: @store, permission_key: "purchasing.vendor.manage") != :allow
        @vendor.errors.add(:base, "not permitted to manage vendors")
        return false
      end

      ActiveRecord::Base.transaction do
        @vendor.save!

        Administration::RecordAuditEvent.call(
          actor: @actor,
          organization: @organization,
          action: "vendor.created",
          subject: @vendor,
          metadata: {
            "code" => @vendor.code,
            "after" => Administration::ChangeMetadata.snapshot(@vendor, TRACKED_ATTRIBUTES)
          }
        )
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
