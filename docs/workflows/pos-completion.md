# Workflow: POS Transaction Completion

**Status:** Delivered in Phase 4c (quantity/`none`); extended in 4d (individual) and 4e (linked returns); card recovery under ADR-0016  
**Type:** Record-level workflow  
**Governing:** ADR-0008, ADR-0009, ADR-0014, ADR-0016; [point-of-sale](../domains/point-of-sale.md); [service-catalog](../implementation/service-catalog.md)

## Purpose

Atomically finish an open POS Transaction: revalidate commercial totals, settle tenders, post inventory effects, assign a receipt number only on success, and mark lines/tenders/transaction completed.

## Preconditions

- Open Business Day and open completion Session that controls the Transaction (`active_pos_session_id`).
- Actor has `pos.transaction.complete` (and tender permissions already used to create tenders).
- Unresolved tenders net-settle the recalculated transaction net.
- No `void_required` card tenders remain (ADR-0016).
- No tax blockers from `Pos::RecalculateTransaction` / `Tax::CalculateTransaction` (missing store tax rules block).

## Ordered steps (`Pos::CompleteTransaction`)

1. Lock Transaction; replay if already completed under the same `completion_idempotency_key`.
2. Lock Session; confirm open day and session control.
3. Recalculate under lock; fail on blockers.
4. Lock pending lines and unresolved tenders; reject if any `void_required` tenders exist; validate departments and tender settlement.
5. For each pending product line:
   - `direction: return` → `Inventory::PostCustomerReturn`
   - otherwise quantity/individual tracked → `Inventory::ConvertReservation` (sale ledger / unit sold)
   - `none` tracking → no inventory posting
6. Mark lines and tenders `completed`.
7. Lock Store; increment `next_receipt_sequence`; assign `receipt_number` / `receipt_sequence`.
8. Mark Transaction `completed` with totals snapshots; audit; commit.

## Failure behavior

Any raise rolls back the entire database transaction: no partial inventory, no consumed receipt number, no completed status.

## Idempotency

Repeating the same `completion_idempotency_key` on an already-completed Transaction returns the prior success without re-posting.

## Related

- [quantity-tracked-sale.md](quantity-tracked-sale.md)
- [customer-return.md](customer-return.md)
- [suspended-transaction.md](suspended-transaction.md)
- [cancel-transaction.md](cancel-transaction.md)
- [post-void.md](post-void.md)
