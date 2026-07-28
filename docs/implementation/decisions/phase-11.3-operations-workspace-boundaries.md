# Phase 11.3 — Operations workspace boundaries

**Status:** Accepted  
**Needed by:** Phase 11.3  
**Governing area:** Point of Sale / Operations workspace / Reporting and Reconciliation  
**Open decisions:** OD-P11-02, OD-P11-03, OD-P11-04

## OD-P11-02 — Register quick actions versus Operations history

Cash Movement and No Sale remain available as immediate quick actions from Register Ready.

Their authoritative current-session history, review, and management belong to Register Operations.

When no Business Day or POS Session is open, Register may present Open Business Day or Open Session as the next required action. The resulting workflow uses Operations-oriented components.

Close Session belongs in Register Operations. Close Business Day belongs in Store Operations. Detailed Cash Movement, No Sale, Session, and Business-Day history is not duplicated in Register.

Register quick actions are unavailable while a transaction is active, tendering is underway, or Recovery is required.

## OD-P11-03 — Open-transaction workspace navigation

An active POS transaction remains exclusively in Register.

Before navigating to Operations or Store Workspace, the transaction must be:

* completed;
* explicitly suspended; or
* explicitly cancelled.

When an editable transaction has no unresolved tender activity, ShelfStack presents an interruption offering Suspend and continue, Cancel and continue, or Return to Register.

Navigation never silently suspends, cancels, or abandons a transaction.

When tender activity cannot safely be removed, or the transaction is in Recovery, navigation away from Register is blocked until the financial state is resolved.

Ready, suspended-transaction, and completed-Receipt states may navigate normally while preserving Store, Business Day, Session, Device, Drawer, and User context.

## OD-P11-04 — Reconciliation placement in Operations

Operations surfaces reconciliation context but does not duplicate the full reconciliation workspace.

Register Operations shows the current Session’s reconciliation requirement, status, material blockers, and permission-gated links to begin, continue, or view reconciliation.

Store Operations shows the Business Day’s reconciliation status, Sessions awaiting reconciliation, material blockers, and permission-gated links to the applicable Session or Business-Day reconciliation records.

Comparison entry, evidence review, findings, resolutions, correction linking, finalization, and historical reconciliation analysis remain in normal ShelfStack under Reporting and Reconciliation.

Session or Business-Day close may offer Reconcile now or Review later, but reconciliation remains a separate operation and does not become part of the atomic close transaction.

## Consequences

- Phase 11.3 gate issues and wireframes must treat these boundaries as accepted, not open.
- Register Ready keeps Cash Movement / No Sale entry points; history lives in Register Operations.
- Navigation interruptions are explicit; Recovery and unsafe tender state block leave-Register.
- Operations links into ShelfStack reconciliation; it does not embed the full recon product.

## Related

- [architectural-locks.md](../architectural-locks.md#phase-113-operations-workspace-boundaries)
- [open-decisions.md](../open-decisions.md) OD-P11-02–04
- [phase-11.3-pos-operations-workspace.md](../phases/phase-11.3-pos-operations-workspace.md)
- [wireframes.md](../../design/pos/wireframes.md) — Phase 11.3 section
- [phase-07-reporting-and-reconciliation-v1.md](phase-07-reporting-and-reconciliation-v1.md) — close vs reconcile separation
