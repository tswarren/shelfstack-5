# Phase 5 — Supply and Demand

**Status:** Not started  
**Depends on:** Phase 4c (first completed sale) for foundational purchasing; Phase 4d before individual-item supply fulfilment; Phase 4e recommended before return-oriented fulfilment paths  
**Unlocks:** richer ops reporting in Phase 7; request fulfilment against POS  
**Governing docs:** ADR-0005, ADR-0007; [vendors-and-purchasing](../../domains/vendors-and-purchasing.md); [product-requests](../../domains/product-requests.md); [architectural-locks](../architectural-locks.md)

## Goal

Reconnect normal replenishment and customer demand after POS completion works: vendors, purchase orders, receipts, on-order, minimal customers, product requests, and allocations.

## Build order inside this phase

1. Vendors and variant–vendor sources *(foundational; may start after 4c)*  
2. Purchase orders and lines; derived `on_order` *(foundational)*  
3. Receipt posting with PO-line linkage and receipt-based costing *(quantity first; unit-backed receipt lines require 4d)*  
4. Minimal customer/contact shell  
5. Product requests and purchase-order allocations *(quantity paths after 4c; exact-unit fulfilment after 4d)*  
6. In-house request reservation (physical confirm) and allocation coverage  

## Principal tables

Purchasing / receiving:

- `vendors`
- `product_variant_vendors`
- `purchase_orders`
- `purchase_order_lines`
- `receipts`
- `receipt_lines`

Demand:

- minimal `customers` (or equivalent contact shell)
- `product_requests`
- `purchase_order_allocations`

## Purchasing and receiving rules

- Prefer **derived** `on_order` from  
  `ordered − accepted_received − cancelled`.  
  Cache on `stock_balances` only with a single owning posting service.
- Never post `on_order` through the inventory ledger.
- One receipt **header** may include lines from several purchase orders.
- Each receipt **line** references **at most one** purchase-order line.
- One delivery fulfilling several PO lines ⇒ several receipt lines.
- Receipt-based acquisition cost becomes the normal cost source.
- Phase 3 adjustments remain for opening balances and exceptional corrections.

## Customer and requests

- Introduce a **minimal customer/contact** record (identity + contact) before `customer_request`.
- Request types: `customer_request`, `staff_suggestion`.
- Allocations: Phase 3 statuses `active` and `cancelled` only until received/fulfilled posting rules are decided against real receipts.
- Unfulfilled quantity is derived:  
  `requested − active reservations − active allocations`.
- In-house reservation for a request requires physical confirmation.

## Exit criteria

- [ ] Place PO → receive (multi-PO header, one PO line per receipt line) → on-hand increases
- [ ] `on_order` matches derivation from PO lines
- [ ] Customer request allocates PO quantity and/or reserves in-house stock
- [ ] Staff suggestion does not create customer obligations by default
- [ ] Existing Phase 4 sell path still works on received stock

## Out of scope

- Rich CRM, notifications, deposits
- Full RTV / transfer documents
- Advanced PO approval thresholds

## Related

- [../schema-reconciliation-display-categories-and-demand-allocation.md](../schema-reconciliation-display-categories-and-demand-allocation.md)
- [phase-03-quantity-inventory-bootstrap.md](phase-03-quantity-inventory-bootstrap.md)
- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
