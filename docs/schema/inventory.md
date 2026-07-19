# Inventory schema (Phase 3 + 4d units)

**Status:** Implemented (Phase 3 quantity bootstrap; Phase 4d `inventory_units`)  

**Authoritative field notes:** [phase-03-inventory-cost-schema.md](../implementation/phase-03-inventory-cost-schema.md)  
**Domain:** [receiving-and-inventory.md](../domains/receiving-and-inventory.md)

## Tables

| Table | Purpose |
| --- | --- |
| `stock_balances` | Authoritative store × variant quantity and valuation state |
| `inventory_ledger_entries` | Append-only posted movements (`sale`, `customer_return`, adjustments, …) |
| `inventory_reservations` | Active/historical commitments of present stock (quantity or exact unit) |
| `inventory_units` | Exact physical copies (`27` identifiers); individual tracking only |
| `inventory_adjustments` | Draft/posted/cancelled adjustment headers |
| `inventory_adjustment_lines` | One variant per adjustment; posting inputs |
| `inventory_adjustment_reasons` | Organization-scoped controlled reasons by kind |

## Cross-organization invariants

```text
adjustment.store.organization_id
  = reason.organization_id
  = each line.product_variant.organization_id
```

Stock balances and reservations require store and variant in the same organization.

## Concurrency

Primary: `SELECT … FOR UPDATE` on `stock_balances` inside `Inventory::PostLedgerEntry`.  
Secondary: `lock_version` on balances.  
Adjustment headers: `reload.lock!` inside `UpdateAdjustment`, `PostAdjustment`, and `CancelAdjustment`, with draft status rechecked under the lock.  
Reservations: partial unique index on active source identity.

