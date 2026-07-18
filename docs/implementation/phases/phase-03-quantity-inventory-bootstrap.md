# Phase 3 — Quantity Inventory Bootstrap

**Status:** Complete  

**Depends on:** Phase 2  
**Unlocks:** Phase 4a  
**Governing docs:** ADR-0004, ADR-0006, ADR-0013; [receiving-and-inventory](../../domains/receiving-and-inventory.md); [architectural-locks](../architectural-locks.md); [phase-03-inventory-cost-schema.md](../phase-03-inventory-cost-schema.md)

## Goal

Establish authoritative store-level quantity inventory, ledger posting, reservations, and opening stock **without** purchasing or receipts.

## Tracking modes in scope

```text
quantity
none
```

Individual units are Phase 4d.

## Principal tables

- `stock_balances`
- `inventory_ledger_entries`
- `inventory_reservations`
- `inventory_adjustments`
- `inventory_adjustment_lines`
- `inventory_adjustment_reasons` (controlled Classification master; seeded from CSV)

Do **not** require `inventory_cost_variances` or Approval tables for Phase 3 exit.

## Required costing behavior

Phase 3 remains intentionally narrow: balances, ledger posting, reservations, adjustments, and opening stock **without** purchasing or Receipts.

- `inventory_value_cents` on Stock Balance
- cached `moving_average_cost_cents`
- basic `cost_quality` with aggregation and zero-state rules from Inventory Domain
- first positive quantity from zero initializes value and average from incoming cost
- opening inventory with actual, estimated, or unknown cost
- quantity-only adjustments that do not arbitrarily rewrite valuation
- quantity-only crossing into deficit: consume positive value; no full provisional-deficit reconciliation
- quantity from negative toward zero creates no inventory asset value
- positive surplus after negative/zero without retained-cost policy → unknown-cost positive inventory
- explicit positive-balance cost corrections only (`on_hand > 0`, `quantity_delta = 0`)
- unknown value deltas use null, not zero
- ledger quantity and resulting value snapshots
- deterministic rounding
- concurrency and value reconciliation via posting services
- when On Hand ≤ 0, inventory asset value is zero; current `cost_quality` at zero is unknown
- unknown cost never treated as zero
- optional `last_known_unit_cost_*` for later phases

## Services and behavior

1. Stock balance per store × variant; `available = on_hand - reserved - unavailable`; optimistic locking; uniqueness constraint.
2. All on-hand and valuation-state changes via ledger posting services — never direct balance edits. Controllers must not edit Stock Balance valuation fields directly.
3. Typed adjustments per [opening-cost contract](../architectural-locks.md#opening-cost-contract):
   - opening inventory;
   - quantity-only;
   - cost correction.
4. `Inventory::PostLedgerEntry` exclusively owns On Hand and valuation-state changes; `Inventory::CalculateQuantityCost` owns MWA allocation, estimate formula, and quality aggregation used by posting (see [service-catalog.md](../service-catalog.md)).
5. `Inventory::PostAdjustment` coordinates draft → posted adjustment kinds through the posting service with permission checks.
6. Reservation service for `source_type = pos_line_item` (also accept `product_request` in the enum for Phase 5, unused here).
7. **Negative-stock policy:** quantity-tracked variants may reserve/sell beyond available after a visible warning; not inherently an approval event.
8. Concurrency tests for concurrent reserve and adjust, including balance lock + value-state updates.

### Permissions in Phase 3

- `inventory.adjustment.post` for opening / quantity-only
- `inventory.cost_correction.post` + `inventory.cost.view` + reason + audit for cost corrections
- **no** mandatory independent Approval in Phase 3
- numeric correction authority deferred

### Classification in Phase 3

- optional `default_cost_estimation_margin_bps` when estimate path is implemented
- **no** deficit-clearing or cost-variance GL fields

## Must not

- Introduce `receipts` / `receipt_lines` (including unlinked receipts).
- Introduce `inventory_units` or `27` identifiers.
- Introduce vendors, purchase orders, or `on_order` maintenance.
- Let ordinary quantity adjustments silently rewrite moving-average valuation.

## Exit criteria

- [x] Posted opening adjustment creates sellable on-hand for a quantity variant
- [x] Posted opening from zero with known cost initializes aggregate value and average
- [x] Ledger explains the quantity and value delta
- [x] Cost-quality transitions follow Inventory Domain matrix
- [x] Quantity-only adjustment does not arbitrarily rewrite valuation
- [x] Positive cost correction posts only via cost-correction permission + reason + audit
- [x] Negative / zero On Hand keeps inventory asset value at zero; zero balance quality is unknown
- [x] Unknown cost is never treated as zero
- [x] Concurrent reservation tests pass
- [x] Concurrent posting tests cover balance lock + value-state updates
- [x] Negative available with warning behaves per lock
- [x] No receipt tables in schema

## Out of scope

- Receiving, purchasing, product requests
- Individual tracking
- POS sessions and completion
- provisional COGS from POS negative sales (Phase 4c)
- deficit settlement from Receipts (Phase 5)
- `inventory_cost_variances` / settlement tables (OD-014)
- FIFO or proportional deficit allocation (OD-014)
- accounting clearing / export journals
- Receipt-correction allocation
- transfer / RTV / count workflows
- Approval infrastructure for cost corrections

## Related

- [../architectural-locks.md](../architectural-locks.md)
- [../phase-03-inventory-cost-schema.md](../phase-03-inventory-cost-schema.md)
- [../open-decisions.md](../open-decisions.md) (OD-003 accepted; OD-014 open)
- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
