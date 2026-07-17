# Vendors and Purchasing Domain

**Status:** Consolidated specification with open workflow details  
**Domain owner:** Vendor identity, sourcing relationships, acquisition intent, expected supply, and PO allocations

## Governing ADRs

- [ADR-0005: Represent Demand, Supply Allocations, and Inventory Reservations Separately](../adr/0005-demand-allocations-and-reservations.md)
- [ADR-0007: Separate Purchasing, Receiving, and Inventory Events](../adr/0007-purchasing-receiving-and-inventory-events.md)
- [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](../adr/0011-permissions-authority-and-approvals.md)

## Purpose

This domain records the Store's intent to acquire merchandise.

It owns Vendor relationships, expected cost, Purchase Orders, and future-supply commitments. It does not own accepted Receipt quantity or physical inventory.

## Ownership boundary

### Owns

- Vendor;
- Vendor contact and ordering information;
- Vendor terms;
- Product-Variant Vendor Source;
- Purchase Order;
- Purchase-Order Line;
- expected and ordered quantity;
- cancelled quantity;
- expected cost;
- On-Order calculation inputs;
- Purchase-Order Allocation;
- purchasing history.

### References but does not own

- Product and Product Variant;
- Product Request;
- Store;
- Receipt and Receipt Line;
- accepted quantity;
- Inventory Movement;
- Stock Balance;
- completed accounting export.

## Vendor

Suggested attributes:

- Organization;
- stable code;
- name and legal name;
- active status;
- Vendor type;
- currency;
- account reference;
- ordering method and contact;
- phone, email, website;
- default terms;
- return-policy notes;
- internal notes.

An inactive Vendor cannot receive ordinary new Purchase Orders but remains available for history and corrections.

## Vendor Source

A Vendor Source describes how a Vendor supplies one Product Variant.

Suggested attributes:

- Product Variant;
- Vendor;
- Vendor item code;
- Vendor identifier;
- list cost;
- discount rate;
- expected net cost;
- currency;
- minimum quantity;
- order multiple or pack quantity;
- lead time;
- returnable setting;
- preferred status;
- active status;
- last ordered and last received timestamps;
- notes.

A Product-level Vendor relationship may be introduced only if shared sourcing requirements justify it. Variant-level resolution remains authoritative.

A Purchase-Order Line may be created without an existing Vendor Source when policy permits, with a warning and an option to create the Source.

## Purchase Order

A Purchase Order belongs to one receiving Store and normally one Vendor.

Suggested attributes:

- Organization;
- Store;
- Vendor;
- Purchase-Order number;
- commercial status;
- derived receiving state;
- order type;
- currency;
- order and expected dates;
- buyer;
- placement timestamp and User;
- Vendor confirmation;
- shipping information;
- estimated subtotal and freight;
- notes;
- close or cancellation details.

### Status model

The final status model remains Open.

A minimal proposed commercial lifecycle is:

```text
draft
ordered
closed
cancelled
```

A separate derived receiving state may be:

```text
not_received
partially_received
fully_received
```

Whether `submitted` or `received` belongs in the commercial status set requires workflow review.

## Purchase-Order Line

Suggested attributes:

- Purchase Order;
- position;
- Product Variant;
- optional Vendor Source;
- ordered quantity;
- cancelled quantity;
- accepted received quantity cache;
- expected list cost;
- Vendor discount;
- expected net unit cost;
- description, identifier, SKU, and Vendor-code snapshots;
- returnability snapshot;
- notes.

Open quantity:

```text
ordered quantity
- accepted received quantity
- cancelled quantity
```

Only active ordered open quantity contributes to On Order.

## Purchase-Order Allocation

A Purchase-Order Allocation commits expected future supply to a Customer Request.

Suggested attributes:

- Purchase-Order Line;
- Product Request;
- quantity;
- status;
- timestamps.

The allocation status model remains Proposed.

The Phase 3 schema includes only:

```text
active
cancelled
```

`active` means the expected quantity remains committed to the Product Request.

`cancelled` releases the commitment and requires cancellation identity, time, and reason.

The following statuses are deferred until Receiving and Request-fulfilment posting rules exist:

```text
received
fulfilled
```

Receipt posting in Phase 4 must define whether these become persisted statuses, derived states, or separate fulfilment events.

Allocation does not increase On Hand or Reserved physical inventory.

## Workflows

### Create Purchase Order

1. Select Store and Vendor.
2. Add Product Variants.
3. Resolve or create Vendor Sources where useful.
4. Enter quantity and expected cost.
5. Review duplicates, order multiples, and warnings.
6. Save draft.

### Place order

1. Validate Store, Vendor, Variants, quantities, and cost basis.
2. Validate Permission and authority.
3. Snapshot line data.
4. Mark commercially ordered.
5. Include open quantity in On Order.

### Allocate customer demand

1. Identify unallocated open quantity.
2. Select Customer Request.
3. Create Allocation.
4. Prevent total active Allocations from exceeding open supply.
5. Surface Allocation during Receiving and fulfilment.

### Close order

An order may close when all expected quantity has been accepted, remaining quantity has been cancelled, or no further delivery is expected.

Reopening requires an explicit authorized workflow if supported.

## Permissions

```text
purchasing.view_vendors
purchasing.manage_vendors
purchasing.view_vendor_sources
purchasing.manage_vendor_sources
purchasing.view_purchase_orders
purchasing.create_purchase_order
purchasing.edit_draft_purchase_order
purchasing.place_purchase_order
purchasing.allocate_supply
purchasing.cancel_purchase_order
purchasing.close_purchase_order
purchasing.reopen_purchase_order
purchasing.view_cost
```

## Audit requirements

Audit Vendor and Vendor-Source changes, Purchase-Order creation, line additions and removals, quantity and expected-cost changes, order placement, Allocation changes, closure, Cancellation, reopening, User, and reason.

## Invariants

- A Purchase Order belongs to one receiving Store.
- An ordinary Purchase Order normally belongs to one Vendor.
- A Purchase-Order Line identifies one Product Variant.
- Purchasing never changes On Hand.
- On Order is expected supply, not physical inventory.
- Allocation does not create physical Reservation.
- Phase 3 persists only `active` and `cancelled` allocation statuses.
- Active Allocations do not exceed uncommitted open quantity.
- Receiving, not Purchasing, creates inventory.
- Historical lines retain sufficient snapshots.
- Closed or cancelled orders do not accept ordinary activity without explicit reopening.

## Open questions

- What is the final Purchase-Order status set?
- Which Phase 4 events transition an active Allocation to received or fulfilled, and should those states be persisted or derived?
- Is internal submission or approval distinct from Vendor placement?
- Are order numbers Store-specific or Organization-wide?
- Are costs captured as net cost, list and discount, or both?
- How are Vendor-confirmed backorders represented?
- Are Vendor terms Organization-wide, Store-specific, or both?
- Which purchasing amounts require Approval?
- How are freight and landed cost allocated?
- What reopening workflow is permitted?
