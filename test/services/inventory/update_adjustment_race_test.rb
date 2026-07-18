# frozen_string_literal: true

require "test_helper"

module Inventory
  class UpdateAdjustmentRaceTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @variant = product_variants(:sample_book_standard)
      @adjustment = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @user
      )
      @line = InventoryAdjustmentLine.create!(
        inventory_adjustment: @adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: 2,
        input_unit_cost_cents: 100,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
    end

    test "update after post is rejected and leaves posted lines intact" do
      assert PostAdjustment.call(adjustment: @adjustment, actor: @user, store: @store).success?
      line_id = @line.id

      result = UpdateAdjustment.call(
        adjustment: @adjustment.reload,
        attributes: { note: "race" },
        lines_attributes: [
          {
            product_variant_id: @variant.id,
            quantity_delta: 9,
            input_unit_cost_cents: 50,
            input_cost_method: "explicit",
            input_cost_quality: "actual",
            position: 0
          }
        ],
        actor: @user,
        store: @store
      )

      refute result.success?
      assert_match(/draft/i, result.error)
      assert InventoryAdjustmentLine.exists?(line_id)
      assert_equal "posted", @adjustment.reload.status
      assert_equal 2, @adjustment.inventory_adjustment_lines.first.quantity_delta
    end

    test "update after cancel is rejected" do
      assert CancelAdjustment.call(
        adjustment: @adjustment,
        actor: @user,
        store: @store,
        cancel_note: "no longer needed"
      ).success?

      result = UpdateAdjustment.call(
        adjustment: @adjustment.reload,
        attributes: { note: "race" },
        lines_attributes: [],
        actor: @user,
        store: @store
      )

      refute result.success?
      assert_match(/draft/i, result.error)
      assert_equal "cancelled", @adjustment.reload.status
    end

    test "posted line mutation is rejected" do
      assert PostAdjustment.call(adjustment: @adjustment, actor: @user, store: @store).success?
      line = @adjustment.inventory_adjustment_lines.first

      assert_raises(ActiveRecord::RecordNotSaved) do
        line.update!(quantity_delta: 99)
      end
      assert_equal 2, line.reload.quantity_delta
    end

    test "posted line destroy is rejected" do
      assert PostAdjustment.call(adjustment: @adjustment, actor: @user, store: @store).success?
      line = @adjustment.inventory_adjustment_lines.first

      assert_raises(ActiveRecord::RecordNotDestroyed) do
        line.destroy!
      end
      assert InventoryAdjustmentLine.exists?(line.id)
    end
  end

  class UpdateAdjustmentConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      InventoryLedgerEntry.delete_all
      InventoryAdjustmentLine.delete_all
      InventoryAdjustment.delete_all
      InventoryReservation.delete_all
      StockBalance.delete_all

      @store = stores(:main_street)
      @user = users(:admin)
      @variant = product_variants(:sample_book_standard)
    end

    teardown do
      InventoryLedgerEntry.delete_all
      InventoryAdjustmentLine.delete_all
      InventoryAdjustment.delete_all
      InventoryReservation.delete_all
      StockBalance.delete_all
    end

    test "concurrent update and post leave a consistent posted adjustment" do
      adjustment = create_draft!(quantity_delta: 2, unit_cost: 100)
      original_line_id = adjustment.inventory_adjustment_lines.first.id

      post_result = nil
      update_result = nil

      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            post_result = PostAdjustment.call(adjustment: adjustment, actor: @user, store: @store)
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            update_result = UpdateAdjustment.call(
              adjustment: adjustment,
              attributes: { note: "concurrent update" },
              lines_attributes: [
                {
                  product_variant_id: @variant.id,
                  quantity_delta: 9,
                  input_unit_cost_cents: 50,
                  input_cost_method: "explicit",
                  input_cost_quality: "actual",
                  position: 0
                }
              ],
              actor: @user,
              store: @store
            )
          end
        end
      ]
      threads.each(&:join)

      assert post_result.success?, post_result&.error
      adjustment.reload
      assert_equal "posted", adjustment.status

      line = adjustment.inventory_adjustment_lines.first
      assert line.present?
      assert InventoryLedgerEntry.exists?(source: line)

      if update_result.success?
        assert_equal 9, line.quantity_delta
        refute InventoryAdjustmentLine.exists?(original_line_id)
      else
        assert_match(/draft/i, update_result.error)
        assert_equal 2, line.quantity_delta
        assert InventoryAdjustmentLine.exists?(original_line_id)
      end
    end

    test "concurrent update and cancel leave a consistent cancelled adjustment" do
      adjustment = create_draft!(quantity_delta: 2, unit_cost: 100)

      cancel_result = nil
      update_result = nil

      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            cancel_result = CancelAdjustment.call(
              adjustment: adjustment,
              actor: @user,
              store: @store,
              cancel_note: "concurrent cancel"
            )
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            update_result = UpdateAdjustment.call(
              adjustment: adjustment,
              attributes: { note: "concurrent update" },
              lines_attributes: [
                {
                  product_variant_id: @variant.id,
                  quantity_delta: 9,
                  input_unit_cost_cents: 50,
                  input_cost_method: "explicit",
                  input_cost_quality: "actual",
                  position: 0
                }
              ],
              actor: @user,
              store: @store
            )
          end
        end
      ]
      threads.each(&:join)

      assert cancel_result.success?, cancel_result&.error
      adjustment.reload
      assert_equal "cancelled", adjustment.status

      # Update may run before cancel; after cancel it must fail. Either way status is cancelled.
      if update_result.success?
        assert_equal 9, adjustment.inventory_adjustment_lines.first.quantity_delta
      else
        assert_match(/draft/i, update_result.error)
      end
    end

    private

    def create_draft!(quantity_delta:, unit_cost:)
      adjustment = InventoryAdjustment.create!(
        store: @store,
        kind: "opening_inventory",
        status: "draft",
        inventory_adjustment_reason: inventory_adjustment_reasons(:opening_initial),
        created_by_user: @user
      )
      InventoryAdjustmentLine.create!(
        inventory_adjustment: adjustment,
        product_variant: @variant,
        position: 0,
        quantity_delta: quantity_delta,
        input_unit_cost_cents: unit_cost,
        input_cost_method: "explicit",
        input_cost_quality: "actual"
      )
      adjustment
    end
  end
end
