# Inventory schema (Phase 3 + 4d units + Phase 5 receiving)

**Status:** Implemented (Phase 3 quantity bootstrap; Phase 4d `inventory_units`; Phase 5 receipts and OD-014 settlement)

**Authoritative field notes:** [phase-03-inventory-cost-schema.md](../implementation/phase-03-inventory-cost-schema.md)  
**Domain:** [receiving-and-inventory.md](../domains/receiving-and-inventory.md)  
**Related Phase 5 schema:** [purchasing.md](purchasing.md), [product-requests.md](product-requests.md)

## Tables

| Table | Purpose |
| --- | --- |
| `stock_balances` | Authoritative store × variant quantity and valuation state, including open provisional deficit cost |
| `inventory_ledger_entries` | Append-only posted movements (`sale`, `customer_return`, adjustments, `receipt`, `receipt_deficit_settlement`, …); Phase 6 adds `unavailable_delta` / `resulting_unavailable` (ledger-owned aggregate unavailable) and unique `reversal_of_entry_id` |
| `inventory_reservations` | Active/historical commitments of present stock (quantity or exact unit); sources include `pos_line_item` and `product_request` |
| `inventory_units` | Exact physical copies (`27` identifiers); individual tracking only; may record `acquisition_source_type = receipt_line` |
| `inventory_adjustments` | Draft/posted/cancelled adjustment headers |
| `inventory_adjustment_lines` | One variant per adjustment; posting inputs |
| `inventory_adjustment_reasons` | Organization-scoped controlled reasons by kind |
| `receipts` | Draft / posted / cancelled receiving headers (store-scoped `receipt_number`) |
| `receipt_lines` | Delivered / accepted / rejected / accepted-unavailable quantities; optional PO-line link; cost tuple |

## Receipts (Phase 5)

- Header may span multiple purchase orders; each line links to **at most one** purchase-order line.
- Only accepted quantity posts inventory; rejected quantity never does.
- `accepted_unavailable_quantity` remains On Hand but is not sellable / not convertible to request reservations.
- Posting is atomic and idempotent (`receipts.posting_key`).
- Cost tuple on each line: `actual_unit_cost_cents`, `cost_quality`, `cost_provenance`. Controlled provenances include PO/vendor suggestions, `manual_receipt`, `unknown`, and `confirmed_zero`. Unknown and confirmed-zero tuples are enforced in the database; remaining combinations are enforced by model/service validation (full SQL tuple constraint tracked as pre-production hardening).
- On post, resolved costs are snapshotted onto the Receipt Line before inventory movements and reused for ledger posting.

## Allocation → reservation (Phase 5 / OD-007)

When a receipt posts accepted sellable quantity against a PO line that has remaining Customer Request allocations:

1. Inventory for the line is posted first.
2. Remaining allocations convert to `product_request`-sourced `inventory_reservations` in deterministic priority order.
3. Each conversion appends a `converted_to_reservation` event on `purchase_order_allocation_events`, keyed to the originating `receipt_line_id`.

Reservations reduce availability, not `on_hand`.

## Deficit settlement (OD-014)

`stock_balances` carries `open_provisional_deficit_cost_cents` and `deficit_cost_quality`. Quantity-tracked receipts into negative On Hand may post:

1. `receipt_deficit_settlement` — releases provisional deficit cost and records settlement variance facts on the ledger entry;
2. `receipt` — remaining positive quantity at resolved receipt cost.

Completed POS cost snapshots remain immutable.

## Cross-organization invariants

```text
adjustment.store.organization_id
  = reason.organization_id
  = each line.product_variant.organization_id

receipt.store.organization_id
  = receipt.vendor.organization_id
  = each receipt_line.product_variant.organization_id
```

Stock balances and reservations require store and variant in the same organization.

## Concurrency

Primary: `SELECT … FOR UPDATE` on `stock_balances` inside `Inventory::PostLedgerEntry`.  
Secondary: `lock_version` on balances.  
Adjustment headers: `reload.lock!` inside `UpdateAdjustment`, `PostAdjustment`, and `CancelAdjustment`, with draft status rechecked under the lock.  
Receipt posting: lock Receipt → Purchase Orders → Purchase Order Lines → Product Requests, then inventory, then Reservations, then Allocations (ascending id) before conversion events.  
Reservations: partial unique index on active source identity (quantity-tracked); individual units allow multiple active holds per request when distinct units.
