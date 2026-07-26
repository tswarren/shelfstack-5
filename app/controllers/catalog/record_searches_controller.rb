# frozen_string_literal: true

module Catalog
  class RecordSearchesController < ApplicationController
    def index
      record_type = params[:type].to_s
      unless Catalog::SearchRecords::RECORD_TYPES.include?(record_type)
        return render json: { error: "unknown record type" }, status: :unprocessable_entity
      end

      unless Catalog::SearchRecords.authorized?(user: Current.user, store: Current.store, record_type: record_type)
        return render json: { error: "forbidden" }, status: :forbidden
      end

      results = Catalog::SearchRecords.call(
        organization: Current.organization,
        record_type: record_type,
        query: params[:q],
        include_inactive: ActiveModel::Type::Boolean.new.cast(params[:include_inactive]),
        product_id: params[:product_id].presence,
        default_phone_country: Current.store&.country_code,
        labeler: lambda { |record, type|
          type.to_s == "customer" ? customer_search_label(record) : helpers.record_picker_label(record, type)
        }
      )

      render json: {
        results: results.map { |r|
          {
            id: r.id,
            label: r.label,
            status: r.status,
            inactive: r.inactive
          }
        }
      }
    end

    private

    def customer_search_label(customer)
      phone = customer.primary_phone.presence || customer.alternate_phone.presence
      email = customer.primary_email.presence || customer.alternate_email.presence
      references = [ customer.customer_number, phone, email, customer.city ].compact_blank

      ([ customer.display_name.presence || "Customer" ] + references).join(" · ")
    end
  end
end
