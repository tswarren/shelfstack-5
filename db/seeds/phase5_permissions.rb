# frozen_string_literal: true

# Canonical Phase 5 permission definitions (idempotent upsert by code).
# Do not seed inventory.receipt.correct (deferred until correction workflow is accepted).
unless defined?(PHASE5_PERMISSIONS)
  PHASE5_PERMISSIONS = [
    { code: "purchasing.vendor.view", name: "View vendors", permission_group: "purchasing", description: "View vendors" },
    { code: "purchasing.vendor.manage", name: "Manage vendors", permission_group: "purchasing", description: "Create, edit, and deactivate vendors" },
    { code: "purchasing.vendor_source.view", name: "View vendor sources", permission_group: "purchasing", description: "View variant–vendor sources" },
    { code: "purchasing.vendor_source.manage", name: "Manage vendor sources", permission_group: "purchasing", description: "Create, edit, and deactivate variant–vendor sources" },
    { code: "purchasing.cost.view", name: "View purchasing cost", permission_group: "purchasing", description: "View vendor and expected acquisition cost" },
    { code: "purchasing.purchase_order.view", name: "View purchase orders", permission_group: "purchasing", description: "View purchase orders" },
    { code: "purchasing.purchase_order.create", name: "Create purchase orders", permission_group: "purchasing", description: "Create draft purchase orders" },
    { code: "purchasing.purchase_order.edit", name: "Edit draft purchase orders", permission_group: "purchasing", description: "Edit draft purchase orders and lines" },
    { code: "purchasing.purchase_order.place", name: "Place purchase orders", permission_group: "purchasing", description: "Transition a draft PO to ordered" },
    { code: "purchasing.purchase_order.amend", name: "Amend placed purchase orders", permission_group: "purchasing", description: "Cancel placed-line quantity or other permitted placed-order amendments" },
    { code: "purchasing.purchase_order.cancel", name: "Cancel purchase orders", permission_group: "purchasing", description: "Cancel an entirely unreceived PO" },
    { code: "purchasing.purchase_order.close", name: "Close purchase orders", permission_group: "purchasing", description: "Close a fully resolved PO" },
    { code: "purchasing.allocation.create", name: "Create PO allocations", permission_group: "purchasing", description: "Commit open PO quantity to a Customer Request" },
    { code: "purchasing.allocation.release", name: "Release PO allocations", permission_group: "purchasing", description: "Release customer allocation quantity" },
    { code: "requests.product_request.view", name: "View product requests", permission_group: "requests", description: "View Product Requests and buyer review" },
    { code: "requests.product_request.create", name: "Create product requests", permission_group: "requests", description: "Create Product Requests" },
    { code: "requests.product_request.edit", name: "Edit product requests", permission_group: "requests", description: "Edit open requests" },
    { code: "requests.product_request.assign", name: "Assign product request buyers", permission_group: "requests", description: "Assign or reassign a buyer" },
    { code: "requests.product_request.resolve", name: "Resolve product requests", permission_group: "requests", description: "Record the buyer’s terminal decision" },
    { code: "requests.product_request.cancel", name: "Cancel product requests", permission_group: "requests", description: "Cancel a request" },
    { code: "requests.customer_request.reserve", name: "Reserve for customer requests", permission_group: "requests", description: "Commit physically confirmed inventory to a Customer Request" },
    { code: "requests.customer_request.fulfill", name: "Fulfill customer requests", permission_group: "requests", description: "Record Customer Request fulfilment" },
    { code: "inventory.receipt.view", name: "View receipts", permission_group: "inventory", description: "View receipts" },
    { code: "inventory.receipt.create", name: "Create receipts", permission_group: "inventory", description: "Create receiving drafts" },
    { code: "inventory.receipt.post", name: "Post receipts", permission_group: "inventory", description: "Post receipts" },
    { code: "inventory.receipt.receive_unlinked", name: "Receive unlinked lines", permission_group: "inventory", description: "Add a receipt line without a PO-line reference" },
    { code: "inventory.receipt.over_receive", name: "Over-receive", permission_group: "inventory", description: "Accept quantity above the PO open quantity" }
  ].freeze
end

PHASE5_PERMISSIONS.each do |attributes|
  permission = Permission.find_or_initialize_by(code: attributes[:code])
  permission.assign_attributes(attributes.except(:code).merge(active: true))
  permission.save!
end
