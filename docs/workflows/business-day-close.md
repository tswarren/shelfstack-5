# Workflow: Business Day and Session Close

**Status:** Phase 4a/4c service boundaries delivered; Z numbering and reconciliation deferred to Phase 7
**Type:** Record-level workflow
**Governing:** [ADR-0009](../adr/0009-atomic-idempotent-pos-completion.md), [ADR-0010](../adr/0010-business-days-sessions-and-z-reports.md), [ADR-0011](../adr/0011-permissions-authority-and-approvals.md), [point-of-sale domain](../domains/point-of-sale.md), [reporting-and-reconciliation domain](../domains/reporting-and-reconciliation.md), [service-catalog](../implementation/service-catalog.md)

## Purpose

Business Days define store reporting periods. POS Sessions define device/cashier/drawer accountability within a Business Day. Closing a Session stops transaction activity for that session and snapshots cash counts when applicable. Closing a Business Day stops store activity for that reporting period only after all Sessions are closed. Reconciliation remains a separate later workflow.

## Preconditions

- The actor is recorded on open/close/count records; explicit close/open permission checks are not part of the current service boundary and remain a documentation/implementation gap to resolve against ADR-0011.
- A Business Day must be open before a Session can open.
- Only one Business Day may be open per Store.
- A Session must belong to the open Business Day and Store.
- A POS Device cannot have more than one open Session.
- A Cash Drawer cannot have more than one open cash-enabled Session.
- Cash-enabled Sessions require opening cash at open and a closing cash count before close.
- Session close is blocked while the Session controls an open Transaction; unresolved tenders therefore block close through the open-transaction guard.
- Business Day close is blocked while any Session for the Business Day remains open.

## Records read

- Store, actor identity for attribution, POS Device, optional Cash Drawer.
- Business Day and POS Sessions.
- POS Transactions controlled by a Session.
- POS Session Cash Counts and POS Cash Movements for cash-enabled Session close.
- Completed POS Tenders, refunds, and cash movements read by expected-cash calculation.

## Records created or changed

- `Pos::OpenBusinessDay` creates an open Business Day.
- `Pos::CloseBusinessDay` changes Business Day status to `closed` and records close metadata.
- `Pos::OpenSession` creates an open POS Session and, for cash-enabled sessions, an opening `PosSessionCashCount`.
- `Pos::RecordClosingCashCount` appends a closing cash-count row.
- `Pos::CloseSession` changes Session status to `closed` and stores expected/count/variance snapshots for cash-enabled Sessions.
- `Pos::CreateCashMovement` creates session-scoped cash movement records during an open Session.
- Reconciliation records and Z-number records are not created by current close services.

## Transaction boundary

Each open/close/count/cash-movement service owns a database transaction. Session close snapshots expected and counted cash in the same transaction as the status change. Business Day close changes only the Business Day status after confirming no open Sessions under lock.

## Locks

- `Pos::OpenBusinessDay` locks the open-day query for the Store.
- `Pos::CloseBusinessDay` locks the Business Day.
- `Pos::OpenSession` locks the Business Day, then checks/locks open Session conflicts for Device and Drawer.
- `Pos::CloseSession` locks the Session.
- `Pos::RecordClosingCashCount` and `Pos::CreateCashMovement` lock the Session.
- Parent-before-child locking prevents races where a Session opens on a closed Business Day or a Transaction remains open on a closed Session.

## Status transitions

### Business Day

```text
open → closed
```

### POS Session

```text
open → closed
```

No reopen workflow is implemented for closed Sessions or closed Business Days.

## Ledger or snapshot effects

- Session close records closing cash-count snapshots and expected/count/variance values for cash-enabled Sessions.
- Expected cash is calculated as opening cash plus cash received, minus change and cash refunds, plus/minus cash movements.
- Close does not rewrite POS Transactions, Tenders, inventory movements, stored-value ledger entries, or reports.
- Session Z numbering, Business-Day Z numbering, and reconciliation adjustment effects remain deferred.

## Permissions and approvals

Current open/close services carry actor identity but do not implement a dedicated permission check in the service boundary. Cash movements may require approval through `Pos::AuthorizeAction` when their configured Cash Movement Type requires approval. Close and reconciliation permissions are separate; current close does not perform reconciliation. The missing explicit close/open permission boundary should be resolved without using role names directly.

## Failure behavior

- Wrong Store, inactive/closed parent, duplicate open Business Day, duplicate open Device/Drawer Session, missing opening/closing cash count, open Transaction, open Session, validation, or locking failures roll back the attempted service.
- Suspended Transactions remain untouched by Session close; open Transactions block it.
- Cash variance does not by itself rewrite tenders or cash movements.

## Idempotency behavior

- `Pos::CloseBusinessDay` is idempotent when replayed against an already closed Business Day.
- `Pos::CloseSession` is idempotent when replayed against an already closed Session.
- `Pos::CalculateExpectedCash` is read-only/idempotent.
- Open Business Day, Open Session, cash movement creation, and cash-count recording are not idempotent without caller-level retry guards.

## Governing ADR references

- [ADR-0009](../adr/0009-atomic-idempotent-pos-completion.md) — completed POS activity commits atomically before close consumes it as source history.
- [ADR-0010](../adr/0010-business-days-sessions-and-z-reports.md) — Business Day, Session, Device, Drawer, and Z concepts remain distinct.
- [ADR-0011](../adr/0011-permissions-authority-and-approvals.md) — permissions and approvals remain separate.

## Unresolved details

- Business-date assignment policy remains open.
- Session Z numbering, Business-Day Z numbering, X/Z report persistence, and `closed → reconciled` lifecycle are Phase 7 — see [phase-07-reporting-and-reconciliation.md](../implementation/phases/phase-07-reporting-and-reconciliation.md).
- Phase 7 extends close (not only recon): Session close may collect merchant-slip card totals when store `card_reconciliation_grain` is `session`; Business-Day close collects machine/batch card totals when the day has card tenders. Close collects evidence; Z reports it; reconciliation reviews persisted variances.
- Processor settlement automation, chargebacks, and integrated payment batch matching remain deferred.
- No reopen workflow is implemented for closed Business Days or Sessions.
- Explicit permission enforcement for open/close services is not represented in the current service boundary and should be reconciled with ADR-0011 before treating it as settled.
