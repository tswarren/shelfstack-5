# Workflow: Purchase Order — Draft, Place, Amend, Cancel, Close

**Status:** Delivered in Phase 5a/5b/5e; hardened in Phase 5g
**Type:** Record-level workflow
**Governing:** [ADR-0007](../adr/0007-purchasing-receiving-and-inventory-events.md), [ADR-0011](../adr/0011-permissions-authority-and-approvals.md), [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md), [vendors-and-purchasing](../domains/vendors-and-purchasing.md), [ordering-and-acquisition-planning](../domains/ordering-and-acquisition-planning.md), [service-catalog](../implementation/service-catalog.md)

## Purpose

A Purchase Order records the store's intent to acquire merchandise from a vendor. It creates expected supply only; it never changes `on_hand`. Accepted receipt posting is the service boundary that creates inventory and advances received quantities.

## Preconditions

- The actor has store-context purchasing permission for the requested action.
- The Store and Vendor are active and belong to the same Organization.
- Lines resolve exact Product Variants; a Product is not ordered as sellable supply without a Variant.
- Draft create/update lines include order quantity and expected cost inputs consistent with current purchasing schema.
- Placement requires a draft Purchase Order.
- Amendment requires an ordered Purchase Order; placed line identity, original quantity, and cost snapshots are immutable.
- Cancellation requires a draft or ordered Purchase Order with no received quantity on any line.
- Closing requires an ordered Purchase Order whose every line has zero derived open quantity and no remaining Purchase-Order Allocation quantity.

## Records read

- Store, Organization, Vendor, Product Variant, Vendor Source, actor Membership/Permission records.
- Purchase Order and Purchase Order Lines for update/place/amend/cancel/close.
- Purchase-Order Allocations and Allocation Events when amendments or cancellation release committed customer-request allocations.
- Receipt Lines are historical sources that advanced stored line received quantities during receipt posting; ordinary Purchase Order projections do not reread Receipt Lines.

## Records created or changed

- `Purchasing::CreatePurchaseOrder` creates a draft Purchase Order, store-scoped never-reused order number, Purchase Order Lines, line snapshots, and audit metadata.
- `Purchasing::UpdateDraftPurchaseOrder` updates draft header data and synchronizes the draft line set, updating submitted existing lines in place, adding new lines, and deleting omitted lines.
- `Purchasing::PlacePurchaseOrder` changes status to `ordered` and records ordered timestamp/user/date.
- `Purchasing::AmendPurchaseOrder` increases supply by adding new lines or decreases expected supply by increasing `cancelled_quantity`; it never edits placed line identity fields in place.
- `Purchasing::CancelPurchaseOrder` changes status to `cancelled`, records cancellation metadata, and releases remaining allocations on its lines.
- `Purchasing::ClosePurchaseOrder` changes status to `closed` and records close metadata.
- No Purchase Order workflow writes `StockBalance`, `InventoryLedgerEntry`, `InventoryUnit`, or `InventoryReservation` directly.

## Transaction boundary

Each application service owns one database transaction for its workflow step. Allocation releases required by amendment or cancellation occur in the same transaction as the Purchase Order change so expected supply and committed customer demand cannot diverge.

## Locks

- Create locks the Store while assigning the order number.
- Draft update, placement, cancellation, and close lock the Purchase Order.
- Amendment locks the Purchase Order and then affected Purchase Order Lines.
- Allocation release paths lock affected allocations through `Purchasing::ReleaseAllocation` semantics.
- Receiving locks Purchase Order Lines from `Inventory::PostReceipt`, not from the Purchase Order services.

## Status transitions

```text
draft → ordered
 draft → cancelled
ordered → cancelled   (only before any receipt quantity)
ordered → closed      (only when every line's open quantity is zero)
```

There is no implemented reopen workflow. Receiving state (`not_received`, `partially_received`, `fully_received`) and `on_order` are derived from line quantities and receipt facts, not stored as commercial statuses.

## Ledger or snapshot effects

- Purchase Order lines preserve description, SKU/identifier, vendor item, returnability, expected cost, and related line snapshots needed to explain later receiving and reporting.
- Purchase Orders do not post inventory ledger entries and do not create inventory value.
- Purchase-Order Allocation Events are append-only facts for release or receipt-to-reservation conversion.

## Permissions and approvals

Implemented permissions are service-specific and store-scoped, including `purchasing.purchase_order.*` for Purchase Order operations and `purchasing.allocation.*` for allocation/release operations. Numeric purchasing approval thresholds remain an open/deferred decision; current placement records warnings for MOQ/order-multiple concerns but does not enforce approval thresholds.

## Failure behavior

- Validation or permission failure rolls back the whole service transaction.
- Placement rejects non-draft orders.
- Draft update rejects non-draft orders.
- Amendment rejects reductions that would make open quantity less than remaining allocated quantity unless matching releases are included.
- Cancellation rejects closed orders and orders with any received quantity.
- Close rejects orders with remaining open quantity or remaining allocated quantity.
- Soft MOQ/order-multiple warnings do not block placement.

## Idempotency behavior

- Replaying `PlacePurchaseOrder` on an already ordered Purchase Order is a no-op success.
- Replaying `CancelPurchaseOrder` on an already cancelled Purchase Order is a no-op success.
- Replaying `ClosePurchaseOrder` on an already closed Purchase Order is a no-op success.
- Create, draft update, and amendment are not idempotent unless a caller supplies a higher-level retry guard.
- Allocation release supports posting-key idempotency in the allocation service, not on the Purchase Order row itself.

## Governing ADR references

- [ADR-0007](../adr/0007-purchasing-receiving-and-inventory-events.md) — separates purchase orders, receipts, and inventory events.
- [ADR-0011](../adr/0011-permissions-authority-and-approvals.md) — separates permissions, numeric authority, and approvals.
- [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md) — distinguishes customer demand, PO allocation, and physical reservation.

## Unresolved details

- Detailed purchase-order approval thresholds and numeric authority are not settled.
- Vendor acknowledgement, transmission, cancellation acknowledgements, backorder cascade, and return-to-vendor flows remain deferred.
- Reopen-after-close is not implemented.
- Vendor availability integrations are not implemented; current warnings and buyer review remain local workflow behavior.
