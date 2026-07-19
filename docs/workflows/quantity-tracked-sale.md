# Workflow: Quantity-Tracked Sale

**Status:** Delivered in Phase 4c  
**Type:** Record-level workflow  
**Governing:** ADR-0006, ADR-0009, ADR-0013, OD-014 interim; [receiving-and-inventory](../domains/receiving-and-inventory.md)

## Purpose

Sell interchangeable quantity-tracked merchandise from store On Hand through POS, converting a Reservation into an outbound `sale` ledger movement with cost snapshots on the line.

## Preconditions

- Open Session controlling an open Transaction.
- Variant `inventory_tracking_mode = quantity`.
- Sufficient available quantity preferred; negative available warns but does not block (OD-014 provisional deficit cost).

## Sequence

1. `Pos::AddLine` → `Inventory::Reserve` (increments `reserved`; does not change `on_hand`).
2. Commercial edits / tax via `Pos::RecalculateTransaction` while `PosTransaction#editable?`.
3. Tender(s); tender-state lock while unresolved.
4. `Pos::CompleteTransaction` → `Inventory::ConvertReservation` → `PostLedgerEntry` (`movement_type: sale`).
5. Reservation `converted`; line cost snapshots set; `on_hand` reduced by sale quantity.

## Related

- [pos-completion.md](pos-completion.md)
- [opening-stock.md](opening-stock.md)
