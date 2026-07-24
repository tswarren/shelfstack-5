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
        labeler: ->(record, type) { helpers.record_picker_label(record, type) }
      )

      render json: {
        results: results.map { |r| { id: r.id, label: r.label } }
      }
    end
  end
end
