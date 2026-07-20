# frozen_string_literal: true

require "test_helper"

module Pos
  class InactiveDepartmentOpenRingTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @admin = users(:admin)
      _day, @session = pos_open_cash_session(
        store: @store, device: pos_devices(:register_1),
        drawer: cash_drawers(:drawer_1), actor: @admin
      )
      @transaction = OpenTransaction.call(pos_session: @session, actor: @admin).pos_transaction
      @department = departments(:books_new)
    end

    test "rejects inactive department for open-ring line" do
      @department.update!(active: false)

      result = AddOpenRingLine.call(
        pos_transaction: @transaction, department: @department,
        unit_price_cents: 500, actor: @admin
      )

      refute result.success?
      assert_match(/department must be active/i, result.error)
    end
  end
end
