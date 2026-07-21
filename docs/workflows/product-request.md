# Workflow: Product Request — Demand, Buyer Review, Allocation, Fulfilment

**Status:** Delivered in Phase 5d/5e/5f (creation, buyer review, allocation, reservation, fulfilment); hardened in Phase 5g

**Type:** Record-level workflow (minimal stub — see governing domain doc for full detail)
**Governing:** [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md); [OD-007](../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md); [product-requests](../domains/product-requests.md); [ordering-and-acquisition-planning](../domains/ordering-and-acquisition-planning.md); [phase-05-supply-and-demand](../implementation/phases/phase-05-supply-and-demand.md); [service-catalog](../implementation/service-catalog.md) (Phase 5d/5e/5f entries)

## Purpose

A Product Request records why the store may want merchandise — customer demand or one
of three non-customer buyer-decision types. It never increases On Hand or On Order by
itself.

## Summary sequence

### Non-customer requests (`staff_suggestion` / `stock_replenishment` / `frontlist_selection`)

```text
open (CreateProductRequest)
  → buyer review (read-only projection: Purchasing::ReplenishmentSnapshot)
    → resolve: ordered | declined | deferred | duplicate | superseded | no_longer_needed
      (ResolveProductRequest; "ordered" typically pairs with
      Purchasing::AddDemandToDraftPurchaseOrder — never creates a
      Purchase-Order Allocation, per ADR-0015)
```

### Customer requests

```text
open (CreateProductRequest)
  → optional Purchase-Order Allocation against an open PO line
    (Purchasing::CreateAllocation / ReleaseAllocation — commits expected,
    not physical, supply)
  → optional in-house reservation of already-counted stock
    (Requests::ReserveInHouseInventory — requires physically_confirmed: true)
  → receipt posting may convert a remaining allocation into an
    Inventory Reservation (Inventory::PostReceipt, Phase 5f)
  → POS sale linked to the request records fulfilment
    (Requests::RecordFulfillment, called from Pos::CompleteTransaction);
    a linked return reverses it (Requests::ReverseFulfillment)
  → fulfilled once fulfilled_quantity >= requested_quantity
```

`uncovered_quantity = requested − fulfilled − active_reserved − remaining_allocated`
(never double-counted; see the Phase 5e/5f service-catalog notes for the exact derived
quantities and event-sourcing detail).

## Records read / created

See the Phase 5d/5e/5f rows in [service-catalog.md](../implementation/service-catalog.md)
for exact services, locks, transactional/idempotency guarantees, and permission keys
(`requests.product_request.*`, `requests.customer_request.*`, `purchasing.allocation.*`).
This stub intentionally does not duplicate that detail — update the service catalog
first when behavior changes.

## Related workflows

- [purchase-order.md](purchase-order.md) — where non-customer demand and Customer
  Request allocations land
- [pos-completion.md](pos-completion.md) — where Customer Request fulfilment is
  recorded atomically with sale completion
