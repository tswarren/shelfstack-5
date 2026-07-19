# Workflow: Suspend and Recall Transaction

**Status:** Delivered in Phase 4a  
**Type:** Record-level workflow  
**Governing:** ADR-0010; [point-of-sale](../domains/point-of-sale.md)

## Purpose

Park an open Transaction with Reservations held, clear active session control, and later recall it onto another open Session for completion.

## Sequence

1. `Pos::SuspendTransaction` — status `suspended`; reservations remain; blocked if unresolved tenders exist (4c).
2. Session may close while suspended Transactions remain (open Transactions block close).
3. `Pos::RecallTransaction` on a new open Session — sets `active_pos_session_id`; only one register may control a Transaction at a time.
4. Later completion reports to the completing Session / its Business Day.

## Related

- [pos-completion.md](pos-completion.md)
