# frozen_string_literal: true

require "test_helper"

module Customers
  class DeactivateTest < ActiveSupport::TestCase
    setup do
      @customer = customers(:riverside_school)
      @admin = users(:admin)
      @store = stores(:main_street)
    end

    test "deactivates and records audit in one outcome" do
      assert_difference "AdministrativeAuditEvent.where(action: 'customers.customer.deactivated').count", 1 do
        result = Deactivate.call(customer: @customer, actor: @admin, store: @store)
        assert result.success?, result.error
      end

      assert_not @customer.reload.active?
    end
  end
end
