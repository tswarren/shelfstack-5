# Product Requests Domain

**Status:** Consolidated specification  
**Domain owner:** Demand, request lifecycle, buyer-review state, coverage, and fulfilment summary

## Governing ADRs and decisions

- [ADR-0015: Require Product-Backed Demand and Reserve Supply Allocations for Customer Commitments](../adr/0015-product-backed-demand-and-customer-supply-commitments.md)
- [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](../adr/0006-inventory-quantities-and-reservation-records.md)
- [OD-007 allocation receipt and fulfilment](../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md)
- [Ordering and Acquisition Planning](ordering-and-acquisition-planning.md)

## Purpose

This domain records demand that the Store may attempt to fulfil.

It unifies Customer Requests, staff purchasing suggestions, stock replenishment, frontlist selections, future automated replenishment suggestions, and buyer-review demand.

It does not merge demand with supply. Product Requests, Purchase-Order Allocations, Inventory Reservations, Purchase Orders, Receipts, and Product Request Fulfilments remain separate facts.

Every acquisition-demand record references an existing ShelfStack Product (ADR-0015). Free-text notes may preserve context but do not substitute for product identity.

## Ownership boundary

### Owns

- Product Request;
- request type;
- requested / proposed quantity;
- priority;
- needed-by date;
- requesting User;
- nullable opaque Customer reference for v1;
- request notes;
- request lifecycle and non-customer buyer resolution;
- fulfilment summary and buyer-review state;
- Product Request Fulfilment facts (with POS / Inventory references).

### References but does not own

- Product and Product Variant;
- Inventory Reservation, owned by Receiving and Inventory;
- Purchase-Order Allocation, owned by Vendors and Purchasing;
- Purchase Order and Receipt;
- POS Transaction / Line used for final fulfilment;
- future Customer master data.

## Request types

Initial types:

```text
customer_request
staff_suggestion
stock_replenishment
frontlist_selection
```

Potential future type:

```text
system_replenishment_suggestion
```

### Customer Request

Represents customer demand and a continuing fulfilment obligation. Remains open through ordering, receiving, reservation, and fulfilment until resolved.

### Staff Suggestion / Stock Replenishment / Frontlist Selection

Buyer-decision records. They enter buyer review and normally close when the buyer orders, declines, or otherwise resolves them. They do not create customer obligations and do not ordinarily create Purchase-Order Allocations (ADR-0015).

## Product Request

Suggested attributes:

- Store;
- request type;
- nullable `customer_reference` for Customer Requests;
- required Product;
- optional Product Variant;
- requested / proposed quantity;
- priority (Customer Requests);
- needed-by date;
- status;
- requesting User;
- assigned buyer;
- notes;
- for non-customer resolution: resolution code, buyer-selected quantity, resolving User, resolution time, note;
- timestamps.

```text
product_requests.product_id → required
product_requests.product_variant_id → nullable until exact configuration known
```

Before merchandise is added to a Purchase Order, the exact Product Variant must be resolved.

Suggested high-level statuses:

```text
open
fulfilled
declined
cancelled
closed
```

Suggested non-customer resolution codes:

```text
ordered
declined
deferred
duplicate
superseded
no_longer_needed
```

`deferred` may leave the request open. Whether resolution fields live on the request or a resolution-event table remains an implementation detail (ADR-0015 open details).

## V1 Customer reference

No `customers` table in Phase 5. Customer Requests may store a nullable opaque `customer_reference`. See [architectural-locks.md](../implementation/architectural-locks.md).

## Supply coverage (Customer Requests)

A Customer Request may be covered by physically confirmed Inventory Reservations and remaining Purchase-Order Allocations.

```text
requested quantity
− confirmed active Inventory Reservations
− remaining Purchase-Order Allocations
= unfulfilled quantity
```

Coverage must not exceed requested quantity without an explicit request-quantity change.

Purchase-Order Allocations are reserved for Customer Requests. Non-customer ordered merchandise becomes general expected supply and, after receipt, general stock unless separately reserved.

## Customer Request workflow

1. Physically confirm present inventory → Inventory Reservation.
2. Allocate compatible unallocated On-Order supply → Purchase-Order Allocation.
3. Remaining quantity enters buyer review.
4. On receipt of usable allocated supply → convert allocation to Inventory Reservation (OD-007).
5. Final sale or delivery → Product Request Fulfilment; close when fulfilled.

Compatible Customer Requests are ranked by authorized priority, needed-by date, then creation time. Earlier compatible supply may release redundant future allocations.

## Non-customer request workflow

1. Resolve or create Product (and optional Variant).
2. Create request; enter buyer review while open.
3. Buyer orders (possibly a different quantity), declines, defers, or closes.
4. Close with resolution; PO line records what was ordered.
5. No continuing allocation; PO cancellation does not automatically reopen the request.

When a buyer orders less than proposed, close with the ordered quantity and create a follow-up request for residual demand if the buyer wants it reconsidered.

## Product Request Fulfilment

Final fulfilment is not an allocation or reservation status. Persist a fulfilment fact identifying at minimum:

```text
product_request_id
inventory_reservation_id
pos_line_item_id
quantity
fulfilled_at
fulfilled_by_user_id
```

Supports partial fulfilment across several POS transactions and reservations. `pos_line_item_id` may later generalize for non-POS delivery.

Linked returns and Phase 6 post-void of a fulfilled sale append `kind: reverse` facts through `Requests::ReverseFulfillment` (never edit the original fulfil fact). See [Phase 6 post-void eligibility](../implementation/decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md).

## Buyer-review queue

Derived projection over open Product Requests and coverage. Not a PO-line flag, Product status, or inventory quantity. Customer obligations and non-customer open decisions must remain distinguishable.

## Permissions

Canonical keys: [authorization-permissions.md](authorization-permissions.md).

```text
requests.product_request.view
requests.product_request.create
requests.product_request.edit
requests.product_request.assign
requests.product_request.resolve
requests.product_request.cancel
requests.customer_request.reserve
requests.customer_request.fulfill
```

`resolve` records the buyer’s terminal decision for the applicable request type (including decline). There is no separate decline or close permission; fulfilment or resolve drives terminal status. On-order allocation uses `purchasing.allocation.create` / `purchasing.allocation.release`. Unclaimed holds use `inventory.reservation.release`.

## Audit requirements

Audit Request creation, Product/quantity changes, priority and needed-by changes, buyer assignment, buyer resolution (including decline), Allocation and Reservation references, fulfilment, Cancellation, User, and reason. Product creation from demand entry is audited in Catalog.

## Invariants

- Every Request references an existing ShelfStack Product.
- A Request represents demand, not supply.
- Creating a Request does not change On Hand or On Order.
- Purchase-Order Allocations commit expected supply only to Customer Requests.
- Inventory Reservations commit physically present supply; in-house holds require physical confirmation.
- Staff Suggestions, stock replenishment, and frontlist selections do not ordinarily create customer obligations or allocations.
- Active coverage must not exceed requested quantity without an explicit change.
- V1 Customer Requests use `customer_reference` only.

## Open questions

Phase 5 scaffolding defaults are locked in [phase-05-supply-and-demand.md](../implementation/phases/phase-05-supply-and-demand.md) (resolution columns, follow-up on partial order, optional supersession, `inventory.reservation.release` for unclaimed holds). Remaining later work:

- Whether a non-authoritative non-customer ↔ PO navigation hint is worth implementing.
- Substitution authorization (out of Phase 5).
- Whether every fulfilment must require a POS Transaction in every future case (Phase 5 baseline assumes POS fulfilment fact).
