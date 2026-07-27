# frozen_string_literal: true

module Pos
  # Permission-aware line command availability for Transaction selected-line UI.
  # Uses the same base permissions as the underlying services.
  class LineActions
    def initialize(user:, store:, line:)
      @user = user
      @store = store
      @line = line
    end

    def discount_available?
      sale_line_eligible? && can?("pos.discount.apply")
    end

    def price_override_available?
      sale_line_eligible? && @line.line_kind == "product" && can?("pos.price.override")
    end

    def tax_override_available?
      sale_line_eligible? && can?("pos.tax_category.override")
    end

    def remove_available?
      can?("pos.line.remove")
    end

    private

    def sale_line_eligible?
      @line.sale? && @line.line_kind != "stored_value"
    end

    def can?(permission_key)
      @user.can?(permission_key, store: @store)
    end
  end
end
