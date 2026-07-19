# Workflow: Individually Tracked Sale

**Status:** Delivered in Phase 4d  
**Type:** Record-level workflow  
**Governing:** ADR-0004, ADR-0006; [receiving-and-inventory](../domains/receiving-and-inventory.md)

## Purpose

Sell one exact Inventory Unit (generated `27` identifier) through POS without overselling the unit.

## Sequence

1. Resolve unit (scan `27` via `Pos::ResolveScan` or select) → `Pos::AddLine` with `inventory_unit`.
2. `Inventory::Reserve` locks the unit and sets `status: reserved` (quantity always 1).
3. Completion → `Inventory::ConvertReservation` sets unit `sold` with sold-at / sold-line link; line cost from unit acquisition cost.

## Related

- [pos-completion.md](pos-completion.md)
- [customer-return.md](customer-return.md) (unit restore on `return_to_stock`)
