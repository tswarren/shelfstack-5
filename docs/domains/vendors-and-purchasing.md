# Vendors and Purchasing Domain

**Status:** Consolidated specification  
**Domain owner:** Vendor identity, sourcing relationships, acquisition intent, expected supply, and customer PO allocations

## Governing ADRs and decisions

- [ADR-0015: Require Product-Backed Demand and Reserve Supply Allocations for Customer Commitments](../adr/0015-product-backed-demand-and-customer-supply-commitments.md)
- [ADR-0007: Separate Purchasing, Receiving, and Inventory Events](../adr/0007-purchasing-receiving-and-inventory-events.md)
- [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](../adr/0011-permissions-authority-and-approvals.md)
- [OD-007 allocation receipt and fulfilment](../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md)
- [Ordering and Acquisition Planning](ordering-and-acquisition-planning.md)

## Purpose

This domain records the Store's intent to acquire merchandise.

It owns Vendor relationships, expected cost, Purchase Orders, and Purchase-Order Allocations that commit expected supply to Customer Requests. It does not own accepted Receipt quantity or physical inventory.

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
- expected cost and cost provenance;
- On-Order calculation inputs;
- Purchase-Order Allocation (Customer Requests only);
- purchasing history.

### References but does not own

- Product and Product Variant;
- Product Request;
- Store;
- Receipt and Receipt Line;
- accepted quantity;
- Inventory Movement;
- Stock Balance;
- allocation conversion/release events (coordinated with Receiving / Requests per OD-007);
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
- list cost / cost basis;
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

Variant-level resolution remains authoritative. A Purchase-Order Line may be created without an existing Vendor Source when policy permits, with a warning and an option to create the Source.

### Vendor-term precedence

```text
variant-vendor source
→ store-specific vendor terms (when implemented)
→ organization vendor defaults
→ manual PO entry
```

Final values used on a Purchase-Order Line are snapshotted. Later term changes do not rewrite historical orders.

Vendor minimums, packs, multiples, and free-freight thresholds are shown as warnings before placement. Universal hard enforcement and automatic tier qualification are deferred.

## Purchase Order

A Purchase Order belongs to one receiving Store and normally one Vendor.

Suggested attributes:

- Organization;
- Store;
- Vendor;
- Purchase-Order number (store-scoped; assigned at draft creation; never reused);
- commercial status;
- derived receiving state;
- currency (one per PO; Phase 5 requires store operating currency);
- order and expected dates;
- buyer;
- placement timestamp and User;
- notes;
- close or cancellation details.

### Commercial status (Phase 5 baseline)

```text
draft
ordered
closed
cancelled
```

```text
draft
  ↓ place order
ordered
  ├─ receive partially or fully
  ├─ cancel remaining line quantities
  ├─ cancel entire PO if nothing was received
  ↓ all quantity received or cancelled
closed
```

`ordered` means the store has committed or transmitted the order to the vendor. Placement validates the PO, snapshots line data, records placement user/time, and begins counting open quantity in `on_order`.

There is no separate `submitted` commercial status in Phase 5. Advanced approval routing remains deferred.

### Derived receiving state

```text
not_received
partially_received
fully_received
```

Receiving progress is derived from accepted and cancelled quantities. Do not put `received` in the commercial status set.

### Mutability after placement

After placement, Vendor, Store, currency, and historical line identity are immutable. Do not freely edit ordered quantities or costs in place.

- Reduce expected quantity through explicit `cancelled_quantity` (with user, time, reason).
- Increase ordered quantity by creating a new line or an explicit amendment operation.
- Changing vendors after placement preserves the original line, cancels or releases unsupplied quantity, returns uncovered Customer Request demand to buyer review, and creates a new PO line as needed (ADR-0015).

### Closing and reopening

`closed` means no further ordinary ordering or receiving activity is expected. All remaining open quantity must first be received or cancelled.

**Phase 5 does not support reopening.** A mistakenly closed PO requires an explicit correction or a replacement PO.

## Purchase-Order Line

Suggested attributes:

- Purchase Order;
- position;
- Product Variant (required);
- optional Vendor Source;
- ordered quantity;
- cancelled quantity;
- accepted received quantity;
- cost-entry method (`discount_from_list` | `direct_net_cost`);
- vendor list price / cost basis;
- discount rate;
- expected net unit cost;
- expected extended cost;
- currency;
- cost provenance;
- description, identifier, SKU, and Vendor-code snapshots;
- returnability snapshot;
- notes.

Open quantity:

```text
open_quantity
=
max(
  ordered_quantity
  − accepted_received_quantity
  − cancelled_quantity,
  0
)
```

Constraints:

```text
ordered_quantity > 0
0 <= cancelled_quantity <= ordered_quantity
0 <= accepted_received_quantity
open_quantity >= 0
```

Only open quantity on an active `ordered` Purchase Order contributes to `on_order`.

Authorized over-receipt may accept quantity beyond ordered with warning and confirmation; `on_order` contribution cannot become negative.

Prefer one active draft line per Product Variant and cost/source combination; merge compatible additions; keep separate lines when source, cost basis, returnability, customer allocation, or operational reason differs.

### Expected cost

Phase 5 supports:

```text
discount_from_list
direct_net_cost
```

When a meaningful list-price basis exists, editing discount, net cost, or list price recalculates related fields deterministically in integer cents. For direct-net merchandise, changing a descriptive list price must not silently alter manually entered net cost.

Buyers may bulk-edit discount on selected lines with an audit trail. Automatic tier qualification is deferred.

PO list price is a historical purchasing value distinct from catalog list price and selling price. When they differ, show the comparison; updating catalog or selling prices requires an explicit action.

## Purchase-Order Allocation

A Purchase-Order Allocation commits expected future supply to a **Customer Request** only (ADR-0015).

Staff Suggestions, Stock Replenishment, and Frontlist Selections do not ordinarily create allocations.

Suggested attributes:

- Purchase-Order Line;
- Product Request (Customer Request);
- allocated quantity;
- timestamps;
- creator.

Remaining allocation quantity is derived from append-only conversion and release events (OD-007):

```text
remaining allocation quantity
=
allocated quantity
− converted-to-reservation quantity
− released quantity
```

`received` and `fulfilled` are not persisted allocation statuses. Interface labels such as active / partially resolved / converted / released are projections.

Active remaining allocations must not exceed uncommitted open PO-line quantity. Any operation that reduces open quantity must preserve sufficient allocation coverage, release or reassign allocations, or fail atomically.

Allocation does not increase On Hand or Reserved physical inventory.

## Workflows

### Create Purchase Order

1. Select Store and Vendor.
2. Assign store-scoped PO number.
3. Add Product Variants.
4. Resolve or create Vendor Sources where useful.
5. Enter quantity and expected cost.
6. Review duplicates, order multiples, and vendor-threshold warnings.
7. Save draft.

### Place order

1. Verify still draft; Store and Vendor active.
2. Validate Variants, quantities, packs/multiples (warnings allowed).
3. Validate Permission and authority.
4. Snapshot line data; verify customer allocations ≤ supply.
5. Mark `ordered`; record placement User/time.
6. Include open quantity in derived On Order.
7. Idempotent audit.

### Allocate customer demand

1. Identify unallocated open quantity.
2. Select Customer Request.
3. Create Allocation.
4. Prevent total remaining Allocations from exceeding open supply.
5. Surface Allocation during Receiving and fulfilment (OD-007).

### Close order

Close when all expected quantity has been accepted or cancelled and no further delivery is expected.

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
purchasing.view_cost
purchasing.receive_unlinked   # unexpected deliveries with reason
```

## Audit requirements

Audit Vendor and Vendor-Source changes, Purchase-Order creation, line additions and removals, quantity and expected-cost changes, bulk discount edits, order placement, Allocation creation/release coordination, closure, Cancellation, User, and reason.

## Invariants

- A Purchase Order belongs to one receiving Store.
- An ordinary Purchase Order normally belongs to one Vendor.
- A Purchase-Order Line identifies one Product Variant.
- Purchasing never changes On Hand.
- On Order is expected supply, not physical inventory.
- Purchase-Order Allocations commit expected supply only to Customer Requests.
- Allocation does not create physical Reservation.
- Remaining Allocations do not exceed uncommitted open quantity.
- Receiving, not Purchasing, creates inventory.
- Historical lines retain sufficient snapshots after placement.
- Closed or cancelled orders do not accept ordinary activity; Phase 5 has no reopen workflow.

## Open questions

- How are Vendor-confirmed backorders represented (deferred lifecycle)?
- Are Vendor terms Organization-wide, Store-specific, or both beyond the Phase 5 precedence default?
- Which purchasing amounts require Approval?
- How are freight and landed cost allocated (deferred)?
- Exact schema for allocation events and cached counters (OD-007 open details).
