# Workflow: Purchase Order — Draft, Place, Amend, Cancel, Close

**Status:** Delivered in Phase 5a/5b/5c/5e (draft, amend, cancel, close, allocation); hardened in Phase 5g

**Type:** Record-level workflow (minimal stub — see governing domain doc for full detail)
**Governing:** [ADR-0007](../adr/0007-purchasing-receiving-and-inventory-events.md); [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md); [vendors-and-purchasing](../domains/vendors-and-purchasing.md); [ordering-and-acquisition-planning](../domains/ordering-and-acquisition-planning.md); [phase-05-supply-and-demand](../implementation/phases/phase-05-supply-and-demand.md); [service-catalog](../implementation/service-catalog.md) (Phase 5a/5b/5c/5e entries)

## Purpose

A Purchase Order records the store's intent to acquire merchandise from a vendor. It
never changes On Hand inventory by itself — only a posted Receipt does (see
[opening-stock.md](opening-stock.md) for the non-PO acquisition path, and
`Inventory::PostReceipt` in the service catalog for receiving).

## Summary sequence

```text
draft (vendor + lines, editable, replaceable)
  → ordered (PlacePurchaseOrder; soft MOQ/order-multiple warnings; never blocking)
    → amend (AmendPurchaseOrder: cancel open quantity and/or add new lines; never
      edits placed-line identity/quantity/cost in place)
    → cancel (CancelPurchaseOrder: only if no line has received quantity; releases
      any remaining allocations first)
    → receipt posting reduces open quantity per line (Inventory::PostReceipt,
      Phase 5c) and may convert remaining allocations to Inventory Reservations
      (Phase 5f)
    → close (ClosePurchaseOrder: once every line's open_quantity is zero)
```

Derived `on_order` (`Purchasing::OnOrder`) and `receiving_state`
(`not_received`/`partially_received`/`fully_received`) are always computed from line
quantities, never stored as a commercial status and never posted through the inventory
ledger.

## Records read / created

See the Phase 5a/5b/5c/5e rows in [service-catalog.md](../implementation/service-catalog.md)
for exact services, locks, transactional/idempotency guarantees, and permission keys
(`purchasing.purchase_order.*`, `purchasing.allocation.*`). This stub intentionally does
not duplicate that detail — update the service catalog first when behavior changes.

## Related workflows

- [product-request.md](product-request.md) — how demand reaches a Purchase Order
  (buyer review) and how a Customer Request allocates PO quantity
- [opening-stock.md](opening-stock.md) — acquiring inventory without a PO
- Receiving: `Inventory::PostReceipt` (service catalog, Phase 5c/5f) — no dedicated
  workflow doc yet; tracked as a documentation gap, not a missing capability
