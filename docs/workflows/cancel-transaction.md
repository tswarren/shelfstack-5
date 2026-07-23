# Workflow: Cancel Transaction

**Status:** Delivered in Phase 4a; card recovery under ADR-0016  
**Type:** Record-level workflow  
**Governing:** ADR-0008, ADR-0016; [point-of-sale](../domains/point-of-sale.md); [service-catalog](../implementation/service-catalog.md)

## Purpose

Abandon an open or suspended Transaction without completed sale, inventory, tax, or tender effects: release provisional reservations, soft-remove pending lines, resolve provisional tenders, and mark the Transaction cancelled.

## Preconditions

- Transaction status is `open` or `suspended`.
- Actor has `pos.transaction.cancel`.
- No authorized card tenders remain unresolved (confirm external void first).
- No `void_required` card tenders remain (ADR-0016).

## Ordered steps (`Pos::CancelTransaction`)

1. Lock Transaction; confirm cancellable status and card-recovery blockers.
2. Release or return provisional inventory reservations for pending product lines.
3. Soft-remove pending lines.
4. Resolve remaining unresolved non-card provisional tenders through the ordinary remove path.
5. Mark Transaction `cancelled` with actor, timestamp, and reason.

## Related

- [suspended-transaction.md](suspended-transaction.md)
- [pos-completion.md](pos-completion.md)
