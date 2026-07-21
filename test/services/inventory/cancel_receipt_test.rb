# frozen_string_literal: true

require "test_helper"

module Inventory
  class CancelReceiptTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @receipt = receipts(:draft_receipt)
    end

    test "cancels a draft receipt" do
      result = CancelReceipt.call(receipt: @receipt, actor: @user, store: @store, cancellation_reason: "Wrong shipment")

      assert result.success?, result.error
      assert_not result.replayed
      assert @receipt.reload.cancelled?
      assert_equal "Wrong shipment", @receipt.cancellation_reason
      assert_equal @user, @receipt.cancelled_by_user
    end

    test "replaying an already-cancelled receipt is a no-op success" do
      CancelReceipt.call(receipt: @receipt, actor: @user, store: @store)
      before = AdministrativeAuditEvent.where(action: "inventory.receipt.cancelled").count

      result = CancelReceipt.call(receipt: @receipt, actor: @user, store: @store)

      assert result.success?
      assert result.replayed
      assert_equal before, AdministrativeAuditEvent.where(action: "inventory.receipt.cancelled").count
    end

    test "rejects cancelling a posted receipt" do
      @receipt.update!(status: "posted", posted_at: Time.current, posted_by_user: @user, posting_key: "receipt:#{@receipt.id}")

      result = CancelReceipt.call(receipt: @receipt, actor: @user, store: @store)

      assert_not result.success?
      assert_match(/only draft receipts/i, result.error)
    end
  end
end
