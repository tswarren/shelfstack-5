# Workflow: Receiving — Draft, Cancel, Post, Allocation Conversion

**Status:** Delivered in Phase 5c/5f; hardened in Phase 5g
**Type:** Record-level workflow
**Governing:** [ADR-0004](../adr/0004-store-level-inventory-boundary.md), [ADR-0006](../adr/0006-inventory-quantities-and-reservation-records.md), [ADR-0007](../adr/0007-purchasing-receiving-and-inventory-events.md), [ADR-0013](../adr/0013-govern-quantity-tracked-inventory-cost.md), [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md), [OD-014](../implementation/decisions/od-014-negative-inventory-settlement.md), [receiving-and-inventory](../domains/receiving-and-inventory.md), [purchasing schema](../schema/purchasing.md), [inventory schema](../schema/inventory.md), [service-catalog](../implementation/service-catalog.md)

## Purpose

Receiving records delivered and accepted supply. Only posted accepted receipt quantity creates inventory. Rejected quantity is recorded for receiving history but never becomes inventory. Receipt-line linkage to Purchase Order Lines advances received quantities and may convert customer allocations to physical reservations.

## Preconditions

- The actor has `inventory.receipt.*` permission for the action in Store context.
- The Store, Vendor, Receipt, Receipt Lines, and any linked Purchase Order Lines belong to the same Organization/Store context.
- Draft receipt lines resolve exact Product Variants and accepted/rejected/unavailable quantities according to tracking mode.
- Posting requires a draft Receipt.
- Unlinked lines require `inventory.receipt.receive_unlinked`.
- Over-receipt against linked PO open quantity requires `inventory.receipt.over_receive`.
- Purchase orders do not need to be one-to-one with receipts; a receipt may contain lines from several POs, and linkage is at the receipt-line level.

## Records read

- Store, Vendor, actor Membership/Permission records.
- Receipt and Receipt Lines.
- Product Variant and tracking mode.
- Purchase Order Lines and related allocations/events for linked lines.
- Stock Balances, Inventory Reservations, and Inventory Ledger Entries for quantity-tracked posting and OD-014 settlement.
- Inventory Units for individually tracked receiving where generated.

## Records created or changed

- `Inventory::CreateReceipt` creates a draft Receipt, store-scoped never-reused receipt number, lines, and audit metadata.
- `Inventory::UpdateDraftReceipt` updates draft header data and replaces draft line data.
- `Inventory::CancelReceipt` changes draft status to `cancelled` and records cancellation metadata.
- `Inventory::PostReceipt` changes status to `posted`, records posting metadata, posts accepted inventory effects, advances linked `PurchaseOrderLine#received_quantity`, and writes audit facts.
- Quantity-tracked accepted quantity posts `InventoryLedgerEntry` rows and updates one Store × Variant `StockBalance`.
- Individually tracked accepted quantity creates receipt-sourced `InventoryUnit` records; accepted unavailable quantity creates units in `inspection` status.
- Quantity-tracked linked lines may create/increase `product_request`-sourced `InventoryReservation` rows and append `converted_to_reservation` Purchase-Order Allocation Events.

## Transaction boundary

`Inventory::PostReceipt` is one database transaction for the entire receipt posting. Inventory ledger entries, stock-balance changes, unit creation, Purchase Order Line received quantities, allocation conversion, reservation creation/increase, and posting status commit together or roll back together.

## Locks

- Create locks the Store for receipt-number assignment.
- Draft update, cancellation, and posting lock the Receipt.
- Posting locks each Stock Balance through `FindOrCreateStockBalance` or locks each linked Purchase Order Line.
- Allocation conversion locks Product Requests, Purchase-Order Allocations, and existing Inventory Reservations through the reservation service.
- OD-014 settlement uses the stock-balance/ledger lock path for deterministic deficit-pool updates.

## Status transitions

```text
draft → cancelled
draft → posted
```

Posted receipts are immutable in current implementation; there is no posted receipt correction workflow yet. Purchase Order receiving state remains derived from line quantities after posting.

## Ledger or snapshot effects

- Quantity-tracked accepted quantity creates inventory ledger entries with receipt cost provenance.
- If prior `on_hand` is negative, posting splits into `receipt_deficit_settlement` and `receipt` entries according to OD-014; settlement entries never create inventory value above zero and record settlement variance only on the settlement movement.
- Receipt Line `cost_quality: confirmed_zero` maps to an actual zero unit cost; unknown cost remains unknown/null, never an implied zero.
- Rejected quantity has no inventory ledger effect.
- Receipt-to-reservation conversion appends `converted_to_reservation` allocation events with posting keys scoped to receipt, line, and allocation.

## Permissions and approvals

- `inventory.receipt.post` is required to post any receipt.
- `inventory.receipt.receive_unlinked` is required for unlinked lines.
- `inventory.receipt.over_receive` is required when accepted quantity exceeds linked PO open quantity.
- Receipt-created Inventory Units do not require `inventory.unit.manage`; the receipt-post permission is the service boundary.
- Detailed receiving approvals and correction approvals remain open/deferred.

## Failure behavior

- Permission, validation, status, cost, tracking-mode, locking, or over-receipt failures roll back the entire posting.
- Rejected quantity never posts inventory even when accepted quantity on the same line succeeds.
- Allocation conversion failure rolls back the receipt posting; the system does not leave accepted inventory without matching reservation conversion events for allocations it attempted to convert.
- Posted Receipt correction is not implemented; errors after posting require a future correction/reversal workflow rather than editing the posted receipt.

## Idempotency behavior

- Replaying `Inventory::CancelReceipt` on an already cancelled draft receipt is a no-op success.
- Replaying `Inventory::PostReceipt` on an already posted receipt is a no-op success and does not duplicate ledger entries, units, received quantities, reservations, or allocation events.
- Receipt-to-reservation conversion uses deterministic posting keys for allocation conversion events.
- Create and draft update are not idempotent without caller-level retry guards.

## Governing ADR references

- [ADR-0004](../adr/0004-store-level-inventory-boundary.md) — Store-level inventory ownership.
- [ADR-0006](../adr/0006-inventory-quantities-and-reservation-records.md) — explicit quantities and reservations.
- [ADR-0007](../adr/0007-purchasing-receiving-and-inventory-events.md) — PO intent, receipt acceptance, and inventory events are separate.
- [ADR-0013](../adr/0013-govern-quantity-tracked-inventory-cost.md) — quantity-tracked cost provenance.
- [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md) — allocation and reservation remain separate.
- [OD-014](../implementation/decisions/od-014-negative-inventory-settlement.md) — negative inventory settlement behavior.

## Unresolved details

- Posted receipt correction/reversal workflow is not implemented.
- Detailed RTV, receipt variance approval, invoice matching, and accounting export behavior remain deferred.
- Individually tracked receipt-to-customer-request reservation conversion remains out of scope.
- Receiving unavailable locations/status taxonomy is intentionally minimal; authoritative shelf-location tracking remains deferred.
