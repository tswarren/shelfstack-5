# frozen_string_literal: true

require "application_system_test_case"

# Phase 5g exit-gate coverage: a non-customer Product Request (staff
# suggestion / stock replenishment / frontlist selection) resolves through
# the buyer-review seam into a draft Purchase Order without ever creating a
# Purchase-Order Allocation (ADR-0015 "allocations commit expected supply
# only to Customer Requests").
class NonCustomerResolveWithoutAllocationTest < ApplicationSystemTestCase
  setup do
    @store = stores(:main_street)

    visit new_session_path
    fill_in "Username", with: "admin"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Home"
  end

  test "adding buyer-review demand to a draft PO resolves the request without an allocation" do
    request = product_requests(:open_staff_suggestion)
    assert_equal 0, PurchaseOrderAllocation.count

    visit buyer_review_index_path
    assert_text "Buyer review"

    row = find("tr", text: "Staff Suggestion")
    within(row) do
      # The vendor/quantity inputs use aria-label (not a visible <label>), so
      # target them directly rather than via Capybara's `from:`/label lookup.
      # Ingram has a vendor source (list cost) for this variant; the
      # buyer-review form has no cost fields, so a vendor without a source
      # would fail line validation regardless of allocation behavior.
      find("select[aria-label='Vendor']").select("Ingram Book Company")
      find("input[aria-label='Quantity']").fill_in(with: "5")
      click_button "Add to PO"
    end

    assert_text(/Added 5 unit\(s\) to purchase order/)

    request.reload
    assert_equal "closed", request.status
    assert_equal "ordered", request.resolution
    assert_equal 5, request.resolved_quantity

    assert_equal 0, PurchaseOrderAllocation.count, "non-customer resolution must never create a Purchase-Order Allocation"

    new_line = PurchaseOrderLine.where(product_variant_id: request.product_variant_id).order(:id).last
    assert_equal 5, new_line.ordered_quantity
    assert_equal "draft", new_line.purchase_order.status
  end
end
