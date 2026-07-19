# frozen_string_literal: true

require "test_helper"

module Inventory
  # Phase 4d: "Concurrent reserve of same unit fails safely" (testing.md).
  class ConcurrencyReserveUnitTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      InventoryReservation.delete_all
      InventoryUnit.delete_all

      @store = stores(:main_street)
      @variant = product_variants(:signed_book_standard)
      @user = users(:admin)
      @unit = CreateInventoryUnit.call(
        store: @store, product_variant: @variant, actor: @user, acquisition_cost_cents: 900
      ).inventory_unit
    end

    teardown do
      InventoryReservation.delete_all
      InventoryUnit.delete_all
    end

    test "only one of two concurrent reservations for the same unit succeeds" do
      results = []
      threads = [ 9101, 9102 ].map do |source_id|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            result = Reserve.call(
              store: @store, product_variant: @variant, quantity: 1,
              source_type: "pos_line_item", source_id: source_id, inventory_unit: @unit
            )
            results << result
          end
        rescue StandardError => e
          results << e
        end
      end
      threads.each(&:join)

      successes = results.select { |r| r.respond_to?(:success?) && r.success? }
      failures = results.reject { |r| r.respond_to?(:success?) && r.success? }

      assert_equal 1, successes.size, "expected exactly one winner, got: #{results.inspect}"
      assert_equal 1, failures.size

      failure = failures.first
      failure_message = failure.respond_to?(:error) ? failure.error : failure.message
      assert_match(/already reserved|not available/, failure_message)

      @unit.reload
      assert_equal "reserved", @unit.status
      assert_equal 1, InventoryReservation.active.where(inventory_unit_id: @unit.id).count
    end
  end
end
