# Inventory schema (Phase 3)

**Status:** Implemented (Phase 3 complete)  

**Authoritative field notes:** [phase-03-inventory-cost-schema.md](../implementation/phase-03-inventory-cost-schema.md)  
**Domain:** [receiving-and-inventory.md](../domains/receiving-and-inventory.md)

## Tables

| Table | Purpose |
| --- | --- |
| `stock_balances` | Authoritative store × variant quantity and valuation state |
| `inventory_ledger_entries` | Append-only posted movements |
| `inventory_reservations` | Active/historical commitments of present stock |
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

