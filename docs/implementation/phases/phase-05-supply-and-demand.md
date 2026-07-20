# Phase 5 — Supply and Demand

**Status:** Ready to begin (governing baseline reconciled 2026-07-20)  
**Depends on:** Completed Phase 4 POS, inventory-reservation, exact-unit, UX-baseline, and test-hardening foundations  
**Phase 4 gate status:** 4a–4e, 4f (`34f371f`, PR #30), and 4g (`c51dcca`, PR #31) merged to `main`  
**Unlocks:** richer operations reporting in Phase 7; customer-request fulfilment through POS; later vendor-order lifecycle capabilities  
**Governing docs:** [ADR-0015](../../adr/0015-product-backed-demand-and-customer-supply-commitments.md); [ADR-0007](../../adr/0007-purchasing-receiving-and-inventory-events.md); [ADR-0013](../../adr/0013-govern-quantity-tracked-inventory-cost.md); [OD-007](../decisions/od-007-allocation-receipt-and-fulfilment.md); [OD-014 settlement](../decisions/od-014-negative-inventory-settlement.md); [vendors-and-purchasing](../../domains/vendors-and-purchasing.md); [product-requests](../../domains/product-requests.md); [receiving-and-inventory](../../domains/receiving-and-inventory.md); [ordering-and-acquisition-planning](../../domains/ordering-and-acquisition-planning.md); [lifecycle boundaries](../phase-05-ordering-scope-and-future-lifecycle-boundaries.md); [architectural-locks](../architectural-locks.md)

## Goal

Reconnect completed POS and inventory to bookstore acquisition:

```text
Product
→ acquisition demand
→ buyer review
→ vendor sourcing
→ purchase order
→ receipt
→ physical inventory
→ customer fulfilment or general stock
```

Phase 5 establishes a practical baseline, not a complete enterprise purchasing platform.

### Central decisions

1. All acquisition demand is product-backed (ADR-0015).
2. Customer Requests remain open as fulfilment obligations; non-customer requests are buyer-decision records that normally close when the buyer acts.
3. Purchase-Order Allocations commit expected supply **only** to Customer Requests.
4. Expected supply, physical reservations, and final fulfilment are separate facts (OD-007).
5. Negative inventory is settled at the aggregate Store-and-Variant level on receipt (OD-014).

## Governing distinctions

```text
Product Request              = why the store may want merchandise
Vendor Source                = how a vendor supplies a Product Variant
Purchase Order               = the store’s intent to acquire merchandise
Purchase-Order Allocation    = expected supply committed to a Customer Request
Inventory Reservation        = physically present merchandise committed to a workflow
Receipt                      = merchandise delivered and accepted
Inventory Movement           = the event that changes physical quantity
Product Request Fulfilment   = merchandise actually sold/delivered against a request
```

Creating demand does not increase On Hand or On Order. Creating an allocation does not create physical stock. A reservation does not prove fulfilment.

## Build order

1. Reconcile governing docs (done for ADR-0015, OD-007, OD-014, domains, schema exports, and permission catalog).
2. Vendors and variant-vendor sources (expected-cost method and provenance).
3. Purchase orders and lines (numbering, draft/place, snapshots, cancelled quantities, statuses, derived `on_order`).
4. Receipts and receipt lines (multi-PO, quantity dimensions, atomic posting).
5. Receipt-based positive inventory cost **and** aggregate negative-inventory deficit settlement (OD-014).
6. Product-backed Product Requests and product search/import/create return path.
7. Non-customer resolution and buyer-review queue.
8. Customer Request Purchase-Order Allocations and quantity-resolution events (OD-007).
9. Physical confirmation, Inventory Reservations, receipt-to-reservation conversion, allocation release.
10. Product Request Fulfilment through Phase 4 POS completion.
11. Reconciliation reports and focused concurrency / authorization / idempotency / system tests.

Detail: [ordering-and-acquisition-planning.md](../../domains/ordering-and-acquisition-planning.md). Deferred vendor lifecycle: [phase-05-ordering-scope-and-future-lifecycle-boundaries.md](../phase-05-ordering-scope-and-future-lifecycle-boundaries.md).

## Principal tables / records

### Purchasing and receiving

- `vendors`, `product_variant_vendors`
- `purchase_orders`, `purchase_order_lines`
- `receipts`, `receipt_lines`

### Demand and coverage

- `product_requests` (four initial types; required `product_id`)
- `purchase_order_allocations` (Customer Requests only)
- `purchase_order_allocation_events` (OD-007 conversion/release)
- `product_request_fulfillments`
- existing inventory reservations for present supply

No `customers` table. Buyer-review is a projection, not a table or PO-line flag.

## Phase 5 planning defaults

These close ADR-0015 open details for scaffolding. Do not reopen unless implementation proves a default wrong.

| Topic | Phase 5 default |
| --- | --- |
| Non-customer resolution storage | Columns on `product_requests` (`resolution`, `resolved_quantity`, `resolved_at`, `resolved_by_user_id`, `resolution_note`). No separate resolution-event table. |
| Partial non-customer order | Close the original with the ordered quantity; create a follow-up request only when residual demand should re-enter buyer review. |
| Request supersession | Optional nullable `supersedes_product_request_id` (or equivalent) when a follow-up replaces another; not required for every close. |
| Non-customer ↔ PO correlation | Optional non-authoritative audit/navigation hint only; must not behave as an allocation or coverage fact. |
| Allocation events | Append-only `purchase_order_allocation_events` with `converted_to_reservation` and `released`; remaining quantity derived. Exact columns at migration time per OD-007 / schema dictionary. |
| Fulfilment | Persist `product_request_fulfillments`; Phase 5 baseline links to POS line (+ reservation when applicable). |
| Product from demand | Thin search → import-or-create → return-to-request path. No full external-catalog / ONIX platform. |
| Unclaimed customer reservations | Release via existing `inventory.reservation.release` with reason; no separate expiration engine. |
| Substitutions | Out of Phase 5; do not invent substitution authorization. |

Permissions: [authorization-permissions.md](../../domains/authorization-permissions.md).

## Purchasing and receiving rules (summary)

- Commercial PO statuses: `draft` | `ordered` | `closed` | `cancelled`; receiving progress derived.
- Store-scoped PO numbers at draft creation; no reopen in Phase 5.
- Derived `on_order`; never via inventory ledger.
- Multi-PO receipt headers; at most one PO line per receipt line.
- Only accepted quantity creates inventory; posted receipts immutable.
- Deficit settlement before positive inventory when On Hand is negative (OD-014).
- Expected cost: `discount_from_list` | `direct_net_cost`; bulk discount with audit; threshold warnings.

## Exit criteria

- [ ] Staff can search, import, or create a Product and return to demand entry
- [ ] Every Product Request references a Product; Variant resolved before PO line
- [ ] Four request types enter buyer review with correct obligation semantics
- [ ] Non-customer requests close with auditable resolution and no supply allocations
- [ ] Customer Requests derive reserved / allocated / uncovered quantities without double counting
- [ ] Buyers create/update draft POs from buyer review; place/cancel/close consistently
- [ ] PO lines support discount-from-list and direct-net cost with provenance
- [ ] Derived `on_order` reconciles to ordered, accepted, and cancelled quantities
- [ ] Multi-PO receipts; one PO line per receipt line; atomic/idempotent posting
- [ ] Only accepted quantity increases On Hand; over-receipt / unlinked receive authorized explicitly
- [ ] Receipt into negative On Hand splits deficit settlement and positive inventory correctly
- [ ] Customer Request can allocate PO quantity and reserve physically confirmed stock
- [ ] Receipt converts applicable allocations to Inventory Reservations; earlier supply can release redundant allocations
- [ ] POS completion can create Product Request Fulfilment and close a fulfilled request
- [ ] Existing Phase 4 POS sale paths work with received general stock

## Out of scope / explicitly deferred

Do not design or seed these in Phase 5 scaffolding:

- Customer master / CRM / notifications / deposits (OD-006 v1 stands)
- Posted receipt correction workflow (`inventory.receipt.correct` reserved, not seeded)
- OD-009 store-configuration home; OD-010 unavailable status buckets; OD-013 role/store authority defaults
- Product substitutions and substitution authorization
- Automated replenishment / forecasting; full ONIX / frontlist campaigns
- Vendor EDI / acknowledgements / cascading; automatic tier discounts; hard minimum enforcement
- Freight / landed cost / AP; advanced PO approval routing
- Full RTV / transfers / cross-store consolidation
- Workflow stubs under `docs/workflows/` for purchasing/requests (add as slices land)

## Related

- [../../adr/0015-product-backed-demand-and-customer-supply-commitments.md](../../adr/0015-product-backed-demand-and-customer-supply-commitments.md)
- [../decisions/od-007-allocation-receipt-and-fulfilment.md](../decisions/od-007-allocation-receipt-and-fulfilment.md)
- [../decisions/od-014-negative-inventory-settlement.md](../decisions/od-014-negative-inventory-settlement.md)
- [../../domains/ordering-and-acquisition-planning.md](../../domains/ordering-and-acquisition-planning.md)
- [../phase-05-ordering-scope-and-future-lifecycle-boundaries.md](../phase-05-ordering-scope-and-future-lifecycle-boundaries.md)
- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
- [../deferred-capabilities.md](../deferred-capabilities.md)
