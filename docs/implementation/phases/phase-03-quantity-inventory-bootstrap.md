# Phase 3 — Quantity Inventory Bootstrap

**Status:** Not started  
**Depends on:** Phase 2  
**Unlocks:** Phase 4a  
**Governing docs:** ADR-0004, ADR-0006; [receiving-and-inventory](../../domains/receiving-and-inventory.md); [architectural-locks](../architectural-locks.md)

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

## Services and behavior

1. Stock balance per store × variant; `available = on_hand - reserved - unavailable`; optimistic locking; uniqueness constraint.
2. All on-hand changes via ledger posting services — never direct balance edits.
3. Typed adjustments per [opening-cost contract](../architectural-locks.md#opening-cost-contract):
   - opening inventory;
   - quantity-only;
   - cost correction.
4. Reservation service for `source_type = pos_line_item` (also accept `product_request` in the enum for Phase 5, unused here).
5. **Negative-stock policy:** quantity-tracked variants may reserve/sell beyond available after a visible warning; not inherently an approval event.
6. Concurrency tests for concurrent reserve and adjust.
7. Document interim moving-average behavior when on-hand is zero or negative before Phase 4c.

## Must not

- Introduce `receipts` / `receipt_lines` (including unlinked receipts).
- Introduce `inventory_units` or `27` identifiers.
- Introduce vendors, purchase orders, or `on_order` maintenance.
- Let ordinary quantity adjustments silently rewrite moving-average valuation.

## Exit criteria

- [ ] Posted opening adjustment creates sellable on-hand for a quantity variant
- [ ] Ledger explains the quantity and value delta
- [ ] Concurrent reservation tests pass
- [ ] Negative available with warning behaves per lock
- [ ] No receipt tables in schema

## Out of scope

- Receiving, purchasing, product requests
- Individual tracking
- POS sessions and completion

## Related

- [../architectural-locks.md](../architectural-locks.md)
- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
