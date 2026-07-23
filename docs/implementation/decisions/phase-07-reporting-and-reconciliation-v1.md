# Phase 7 — Reporting and Reconciliation v1 Decisions

**Status:** accepted  
**Needed by:** Phase 7a–7d  
**Governing area:** Reporting / Point of Sale / Authorization  
**Related:** [ADR-0008](../../adr/0008-immutable-pos-transactions.md); [ADR-0010](../../adr/0010-business-days-sessions-and-z-reports.md); [ADR-0011](../../adr/0011-permissions-authority-and-approvals.md); [ADR-0016](../../adr/0016-treat-standalone-credit-card-activity.md); [reporting-and-reconciliation](../../domains/reporting-and-reconciliation.md); [authorization-permissions](../../domains/authorization-permissions.md); [architectural-locks](../architectural-locks.md); [Phase 7](../phases/phase-07-reporting-and-reconciliation.md)

## Decision

Phase 7 delivers close-control reporting (Session/Business-Day X and Z), post-close reconciliation, and a first operational/historical report pack. The choices below close Phase 7 product questions for v1 without adopting deferred capabilities (accounting exports, processor settlement, customer-receipt hardware, BI builders).

**Extensible model underneath; narrow default on top.** Session merchant slips, multi-terminal rows, and received/refunded detail are progressive capabilities — not required vocabulary for ordinary close.

## MVP operating profile

New stores default to:

```text
card_reconciliation_grain = business_day
```

Ordinary first-install workflow:

```text
SESSION CLOSE
  Count drawer (cash-enabled)
  Close session
  — no external card prompt —

BUSINESS-DAY CLOSE
  Confirm all sessions closed
  Enter one terminal/batch net total (+ optional reference)
  Close business day (+ persist Business-Day Z)

RECONCILIATION
  Expected versus observed
  [Reconcile now] or [Review later]
```

Session-grain card reconciliation is an optional tighter-control mode for stores that maintain merchant slips by cashier, can isolate terminal activity by session, and want individual cashier card accountability. Most stores should never enable it.

Default card evidence input is **one net batch total** with optional reference. Additional terminal rows, separate received/refunded amounts, and transaction counts are progressive detail.

## Accepted decisions (1–17)

### 1 — v1 required reports

X/Z family + cash/card recon + first report pack (commercial activity, tender, tax, stock, open PO, SV liability).

### 2 — Print / export

Browser / `@media print` for all four X/Z reports; CSV for tabular pack; no hardware print stack.

### 3 — Card reconciliation scope and evidence

Store setting:

```text
card_reconciliation_grain = session | business_day
```

Default: `business_day`.

| Grain | Session close | Business-day close |
| --- | --- | --- |
| `business_day` | No external card prompt | Collect machine/batch card evidence when the day has card tenders |
| `session` | Collect merchant-slip evidence when the session has card tenders | Still collect machine/batch evidence when the day has card tenders |

**Close collects; Z reports; reconcile reviews.**

Evidence shape:

- One reconciliation scope may contain **one or more** evidence rows (normally by terminal or batch reference).
- Each row has precision `net_only` or `received_and_refunded`.
- `net_only`: store observed net; do not invent fake received/refunded splits.
- `received_and_refunded`: store received and refunded separately; net is derived.
- Optional received/refunded **counts** may be retained.
- MVP UI: one row, net total + optional reference; “add another terminal/batch” and received/refunded fields are progressive.
- Comparisons tie ShelfStack expected to observed using the row’s precision (net, or received/refunded/net).
- Merchant-slip and machine-batch remain distinct comparison types.

### 4 — Reconciliation taxonomy

Comparisons, findings, and resolutions — not a generic balance-changing reconciliation adjustment. Operational corrections use owning-domain mechanisms and may be linked from a resolution.

### 5 — Reconciliation hierarchy and missing evidence

- Session recon only after session close.
- Day recon only after day close and after every included session with configured requirements is reconciled or explicitly excepted.
- Session requirements: cash for cash-enabled; session card only when grain=`session`.
- Day always owns machine/batch card comparison when the day has card tenders.

**Missing required close-time evidence** blocks close by default.

An authorized `evidence_unavailable` exception may permit close **without fabricating an observed amount**:

- records actor, reason, timestamp, and optional terminal/batch applicability;
- second-user approval only when store policy / authority thresholds require it (not mandatory for every MVP case);
- Z snapshot shows the missing-evidence exception;
- comparison may carry an unavailable observed value (no numeric variance until evidence exists or an accept-exception resolution is recorded);
- later reconciliation must explicitly resolve (enter evidence) or accept the exception before that comparison is clear;
- day recon cannot finalize while a required day card comparison remains unresolved `evidence_unavailable` unless an authorized accept-exception resolution exists.

### 6 — Reopen after reconcile

No for v1.

### 7 — Permission ownership

Reconciliation state-change and reporting view/export keys live under `reporting.*`. Close remains `pos.session.close` / `pos.business_day.close`.

Canonical keys (see [authorization-permissions.md](../../domains/authorization-permissions.md)):

```text
reporting.view_*
reporting.export
reporting.reconcile_session
reporting.reconcile_business_day
reporting.record_reconciliation_resolution
reporting.close_evidence_unavailable   # record evidence_unavailable at close when authorized
```

Do not seed `pos.reconcile_*` or `reporting.record_adjustment`.

### 8 — Integrity severity

Close-blocking invariants cover open sessions/transactions, tender/txn net for included activity, Session Z vs activity, Day Z consolidation vs activity, missing required close evidence (unless `evidence_unavailable`), and Z snapshot persistence failure.

Stock/SV ledger mismatches and similar cross-domain diagnostics are reportable exceptions and do not automatically block POS close.

### 9 — Z atomicity and idempotency

Z number + structured snapshot created in the same successful close transaction. Retries do not consume another number. Successful close requires the canonical snapshot.

### 10 — Time attribution

- Business-date assignment: confirm OD-001 (`reporting_date` selected at business-day open).
- Activity attribution: completed POS by completion Business Day; ledger reports by posting timestamp/date; current-state reports by explicit as-of / source cutoff.
- Timezone and source cutoff visible in report metadata.

### 11 — Current vs historical classification

Historical snapshots authoritative for core reports. Current-name navigation not required for Phase 7 core.

### 12 — Z numbering model

Separate store-scoped Session Z and Business-Day Z sequences; unique within namespace; never reused; formatting presentation-only; distinct from any session operating number.

### 13 — Business-Day Z derivation

Persisted Day Z totals consolidate canonical Session Z snapshots (retain breakdown). Close validates the roll-up against included completed activity. Do not persist an independently recalculated alternate commercial total set.

### 14 — Z snapshot and reprint fidelity

Structured snapshot is authoritative (definition version, historical labels, source cutoff, generation metadata, section totals, close evidence). Reprint reproduces that snapshot with historical/numerical equivalence. Byte-identical browser HTML is not required unless a rendered artifact is retained.

### 15 — Reconciliation finalization and mutability

- One canonical reconciliation per Session or Business Day.
- **Close never automatically marks a session or day reconciled**, including when every comparison has zero variance.
- UI may offer one-action “Reconcile now” / “reconcile exact matches” after close; it remains a separate audited finalize action.
- Draft assembly, then finalize with `reconciled_at` / `reconciled_by`.
- After finalization: immutable or append-only superseding corrections only.

### 16 — Variance acceptance authority

| Result | MVP behavior |
| --- | --- |
| Exact match (zero variance) | User with reconcile permission may finalize (one-click allowed) |
| Nonzero variance within user’s configured authority | Same user may explain and accept (reuse cash-style numeric authority; card uses analogous threshold when configured) |
| Variance above authority | Requires another authorized user (ADR-0011 pattern) |
| Evidence unavailable | Reason required; remains unresolved or accepted via authorized exception resolution — do not invent $0 observed |

Close may persist nonzero variance without resolving it. Accepting variance is a reconciliation act. Self-acceptance of over-threshold variance requires distinct elevated self-approval permission, reauthentication, reason, and audit (same pattern as other ADR-0011 self-approvals). Stores without configured thresholds fail closed for accepting differences while still allowing close with proper evidence or `evidence_unavailable`.

### 17 — Pre-Phase-7 closed records

Legacy unsnapshotted (or discard development data). No silent backfill. Any explicit backfill must be marked generated after the original close.

## Pre-7b policy

X-report cash visibility respects blind-count configuration when present. Until blind-count exists, default to showing expected cash to users who can view cash. **Z always retains** expected, counted, and variance.

## Consequences

- Typical independent bookstore sees session cash count, one day batch total, then Reconcile now / Review later.
- Schema supports multi-terminal, received/refunded precision, and session grain without forcing that UI on every store.
- Close and reconcile remain distinct without extra ceremony.
- Domain “Reconciliation Adjustment” as a generic balance mutator is withdrawn in favor of comparisons / findings / resolutions.

## Companion documentation

Governing companions updated with this acceptance:

- [phase-07-reporting-and-reconciliation.md](../phases/phase-07-reporting-and-reconciliation.md)
- [reporting-and-reconciliation.md](../../domains/reporting-and-reconciliation.md)
- [authorization-permissions.md](../../domains/authorization-permissions.md)
- [architectural-locks.md](../architectural-locks.md)
- [business-day-close.md](../../workflows/business-day-close.md)
- [point-of-sale.md](../../domains/point-of-sale.md)
- [open-decisions.md](../open-decisions.md)
- [current-phase.md](../current-phase.md)
- [roadmap.md](../roadmap.md)
