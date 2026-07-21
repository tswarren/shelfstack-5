# frozen_string_literal: true

require "test_helper"

module Inventory
  class UpdateDraftReceiptTest < ActiveSupport::TestCase
    setup do
      @store = stores(:main_street)
      @user = users(:admin)
      @receipt = receipts(:draft_receipt)
      @variant = product_variants(:sample_book_standard)
    end

    test "replaces the line set of a draft receipt" do
      result = UpdateDraftReceipt.call(
        receipt: @receipt,
        attributes: { notes: "Replaced lines" },
        lines_attributes: [
          { product_variant_id: @variant.id, delivered_quantity: 5, accepted_quantity: 5, position: 0 }
        ],
        actor: @user,
        store: @store
      )

      assert result.success?, result.error
      assert_equal 1, result.receipt.receipt_lines.count
      assert_equal 5, result.receipt.receipt_lines.first.accepted_quantity
      assert_equal "Replaced lines", result.receipt.notes
    end

    test "rejects edits once posted" do
      @receipt.update!(status: "posted", posted_at: Time.current, posted_by_user: @user, posting_key: "receipt:#{@receipt.id}")

      result = UpdateDraftReceipt.call(
        receipt: @receipt, attributes: {}, lines_attributes: [], actor: @user, store: @store
      )

      assert_not result.success?
      assert_match(/only draft receipts/i, result.error)
    end
  end
end
