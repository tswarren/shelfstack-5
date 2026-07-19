# Workflow: Linked Customer Return

**Status:** Delivered in Phase 4e  
**Type:** Record-level workflow  
**Governing:** ADR-0008, ADR-0014; [point-of-sale](../domains/point-of-sale.md); [service-catalog](../implementation/service-catalog.md)

## Purpose

Refund merchandise linked to a completed sale line without mutating the original completed line. Restore sellable stock only when disposition is `return_to_stock`.

## Preconditions

- Open Session controlling an open return Transaction (same store as the original sale).
- Original line is a completed `direction: sale` line.
- Actor has `pos.return.create`.
- Return quantity ≤ remaining returnable quantity (original qty minus pending/completed linked returns).

## Sequence

1. `Pos::AddLinkedReturnLine` — creates pending `direction: return` line copying commercial/cost snapshots; reverses historical Discount allocations proportionally (INV-RET-004); links `original_pos_line_item_id`; stores Return Reason + disposition.
2. `Pos::RecalculateTransaction` — reverses original tax components proportionally (does not recalculate current rules for return lines); net uses reversed discounts.
3. `Pos::AddCashRefundTender` when net is negative (`direction: refunded`).
4. `Pos::CompleteTransaction` → `Inventory::PostCustomerReturn`:
   - `return_to_stock` + quantity tracking → inbound `customer_return` ledger
   - `return_to_stock` + individual → unit restored to `available`
   - other dispositions → no sellable stock restore (warning)

## Invariants

- Original sale line attributes and tax rows remain unchanged.
- Corrections are new linked records only (ADR-0008).

## Related

- [pos-completion.md](pos-completion.md)
- [quantity-tracked-sale.md](quantity-tracked-sale.md)
