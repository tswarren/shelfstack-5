# frozen_string_literal: true

module Pos
  # Batch linked returns: loops AddLinkedReturnLine inside one transaction so a
  # mid-batch failure rolls everything back (Phase 11.2D).
  class AddLinkedReturnLines < ApplicationService
    Error = Class.new(StandardError)
    LineSpec = Data.define(:original_pos_line_item, :quantity, :return_reason, :return_disposition)
    Result = Data.define(:pos_line_items, :success?, :error, :warnings)

    def initialize(pos_transaction:, lines:, actor:)
      @pos_transaction = pos_transaction
      @lines = Array(lines)
      @actor = actor
    end

    def call
      raise Error, "select at least one return line" if @lines.empty?

      ActiveRecord::Base.transaction do
        created = []
        warnings = []
        @lines.each do |spec|
          result = AddLinkedReturnLine.call(
            pos_transaction: @pos_transaction,
            original_pos_line_item: spec.original_pos_line_item,
            quantity: spec.quantity,
            return_reason: spec.return_reason,
            return_disposition: spec.return_disposition,
            actor: @actor
          )
          unless result.success?
            raise Error, result.error
          end

          created << result.pos_line_item
          warnings.concat(Array(result.warnings))
        end
        Result.new(pos_line_items: created, success?: true, error: nil, warnings: warnings.uniq)
      end
    rescue Error, ActiveRecord::RecordInvalid => e
      Result.new(pos_line_items: [], success?: false, error: e.message, warnings: [])
    end
  end
end
