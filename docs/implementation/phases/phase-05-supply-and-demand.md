# Phase 5 — Supply and Demand

**Status:** Ready to begin  
**Depends on:** Completed Phase 4 POS, inventory-reservation, exact-unit, UX-baseline, and test-hardening foundations  
**Phase 4 gate status:** 4a–4e, 4f UX Baseline (PR #30, `34f371f`), and 4g test hardening (PR #31, `c51dcca`) are merged to `main`. The Phase 5 integrity, security, and browser gate is satisfied.  
**Unlocks:** richer operations reporting in Phase 7; customer-request fulfilment through POS; later vendor-order lifecycle capabilities  
**Governing docs:** ADR-0005, ADR-0007, ADR-0013; [vendors-and-purchasing](../../domains/vendors-and-purchasing.md); [product-requests](../../domains/product-requests.md); [receiving-and-inventory](../../domains/receiving-and-inventory.md); [ordering-and-acquisition-planning](../../domains/ordering-and-acquisition-planning.md); [phase-05 ordering boundaries](../phase-05-ordering-scope-and-future-lifecycle-boundaries.md); [architectural-locks](../architectural-locks.md)

## Goal

Reconnect normal merchandise acquisition and product-backed demand after POS completion works:

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

Phase 5 introduces vendors, variant-vendor sources, purchase orders, expected cost, receipts, derived `on_order`, product requests, buyer-review demand, purchase-order allocations, and request inventory reservations.

Every acquisition-demand record references an existing ShelfStack product. When the product does not exist, staff create or import it before recording demand.

Phase 5 establishes the initial supply-and-demand workflow without implementing the complete vendor acknowledgement, backorder, cascading, or automated replenishment lifecycle. See [phase-05-ordering-scope-and-future-lifecycle-boundaries.md](../phase-05-ordering-scope-and-future-lifecycle-boundaries.md).

## Governing distinctions

ShelfStack keeps the following records separate:

```text
Product Request          = why the store may want merchandise
Vendor Source            = how a vendor supplies a particular product variant
Purchase Order           = the store’s intent to acquire merchandise
Purchase-Order Allocation = expected incoming supply committed to a customer request
Inventory Reservation    = physically present merchandise committed to an incomplete workflow
Receipt                  = merchandise delivered and accepted
Inventory Movement       = the event that changes physical inventory
```

Creating demand does not increase `on_hand` or `on_order`, create a purchase order, or create an inventory reservation automatically.

## Build order inside this phase

1. **Vendors and variant-vendor sources** — vendor identity, terms, source-specific codes, discounts, expected costs, packs, and multiples.
2. **Purchase orders and lines** — draft/placed workflow; expected-cost entry; line snapshots; derived `on_order`; cancelled and open quantities.
3. **Receipt posting** — multi-PO shipments; one PO-line reference per receipt line; accepted/rejected/unavailable; receipt-based cost; quantity and exact-unit posting.
4. **Product-backed demand entry** — local search; external catalog search where configured; import; minimal manual create; duplicate detection; return to the originating request workflow.
5. **Product requests and buyer-review queue** — customer requests, staff suggestions, stock replenishment, frontlist selections; derived coverage; buyer assignment and disposition.
6. **Purchase-order allocations and in-house reservations** — allocate open incoming quantity; physically confirm present merchandise; reserve quantity or exact units; enforce coverage limits.
7. **Receipt-to-request coverage** — surface related requests; apply customer-demand priority; reserve accepted merchandise; release redundant future allocations; leave uncommitted supply as general stock.

Detail for buyer review, replenishment, cost entry, and sourcing lives in [ordering-and-acquisition-planning.md](../../domains/ordering-and-acquisition-planning.md).

## Principal tables

### Purchasing and receiving

- `vendors`
- `product_variant_vendors`
- `purchase_orders`
- `purchase_order_lines`
- `receipts`
- `receipt_lines`

### Demand and coverage

- `product_requests`
- `purchase_order_allocations`

Phase 5 continues using the existing inventory-reservation structure for physically present supply.

Phase 5 does **not** introduce a `customers` table. Customer requests use a nullable opaque `customer_reference` until the Customer domain is designed.

The buyer-review queue is a projection over product requests, reservations, allocations, and relevant supply. It is not a separate inventory balance or a `to_be_ordered` flag on purchase-order lines.

## Product-backed demand

Every product request must reference a ShelfStack product (`product_id` required). `product_variant_id` may remain nullable until an exact configuration is known. Free-text notes may preserve context but do not substitute for product identity.

Before adding merchandise to a purchase order, ShelfStack must resolve the exact product variant being ordered.

Initial request types:

```text
customer_request
staff_suggestion
stock_replenishment
frontlist_selection
```

Only `customer_request` creates a customer fulfilment obligation. Staff suggestions, stock replenishment, and frontlist selections enter buyer review without creating customer obligations by default.

## Purchasing and receiving rules

- Prefer derived `on_order` from `ordered − accepted_received − cancelled`. Cache on `stock_balances` only with a single owning posting service.
- Never post `on_order` through the inventory ledger.
- Minimal commercial PO statuses: `draft`, `ordered`, `closed`, `cancelled`. Receiving progress is ordinarily derived.
- One receipt header may include lines from several purchase orders.
- Each receipt line references at most one purchase-order line.
- Only accepted quantity creates inventory.
- Receipt-based acquisition cost becomes the normal inventory-cost source.
- Phase 3 adjustments remain for opening balances and exceptional corrections.
- Posted receipts are immutable; corrections use explicit corrective records and inventory movements.
- Receipt posting and associated balance updates must be atomic and idempotent.
- Expected cost supports `discount_from_list` and `direct_net_cost`; bulk discount editing and vendor-threshold warnings are in scope. Automatic tier qualification and hard minimum enforcement are deferred.

## Coverage and priority

```text
requested − active confirmed inventory reservations − active purchase-order allocations
= unfulfilled quantity
```

Coverage must not exceed the request quantity without an explicit request-quantity change. Allocations must not exceed uncommitted open PO quantity.

In-house reservation requires physical confirmation. Compatible customer requests are ranked by authorized priority, needed-by date, then creation time. Redundant future allocations may be reduced or cancelled when earlier compatible supply fulfils a request.

Initial allocation statuses remain `active` and `cancelled`. Whether `received` / `fulfilled` persist, derive, or become separate events remains deferred (OD-007).

## Exit criteria

- [ ] Staff can find, import, or create a product and return directly to demand entry
- [ ] Every acquisition-demand record references a ShelfStack product
- [ ] Customer requests, staff suggestions, stock replenishment, and frontlist selections can enter buyer review
- [ ] Staff suggestions, stock replenishment, and frontlist selections do not create customer obligations
- [ ] Buyer-review quantities correctly reflect reservations, allocations, and remaining demand
- [ ] Buyers can create a PO from selected buyer-review demand
- [ ] PO lines support discount-from-list and direct-net expected cost
- [ ] Selected PO lines can receive a bulk discount change
- [ ] Vendor minimums and order multiples are visible as warnings
- [ ] Placing a PO creates correctly derived `on_order`
- [ ] One receipt can include lines from several POs, with each receipt line referencing at most one PO line
- [ ] Receipt posting increases `on_hand` only for accepted quantity
- [ ] Receipt-based cost updates quantity-tracked or exact-unit inventory cost correctly
- [ ] A customer request can allocate PO quantity and reserve physically confirmed in-house stock
- [ ] Coverage cannot exceed requested quantity or available supply
- [ ] Compatible requests are ranked consistently for fulfilment
- [ ] Redundant allocations can be released when earlier supply fulfils a request
- [ ] Existing Phase 4 POS sale paths work with received stock

## Out of scope

- Customer master records and rich CRM
- Customer notifications, deposits, prepayment, and pickup scheduling
- Automated replenishment and forecasting
- Full frontlist or ONIX campaign management
- Vendor APIs, EDI, and electronic order transmission
- Full vendor acknowledgement and exception lifecycle
- Dedicated backorder management and automatic vendor cascading
- Automatic tiered-discount qualification
- Freight and landed-cost allocation
- Full RTV and transfer documents
- Advanced PO approval thresholds and buyer budgets
- Automated cross-store purchasing consolidation

## Related

- [ordering-and-acquisition-planning.md](../../domains/ordering-and-acquisition-planning.md)
- [phase-05-ordering-scope-and-future-lifecycle-boundaries.md](../phase-05-ordering-scope-and-future-lifecycle-boundaries.md)
- [../schema-reconciliation-display-categories-and-demand-allocation.md](../schema-reconciliation-display-categories-and-demand-allocation.md)
- [phase-03-quantity-inventory-bootstrap.md](phase-03-quantity-inventory-bootstrap.md)
- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
- [deferred-capabilities.md](../deferred-capabilities.md)
