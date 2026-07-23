# Phase 7 — Reporting and Reconciliation

**Status:** 7a decisions accepted — implementation not started  
**Depends on:** Phases 4–6 complete on `main` (posted POS, inventory, purchasing, stored value, corrections)  
**Preferred after:** Phase 6.5 cashier workspace ([phase-06.5-cashier-workspace.md](phase-06.5-cashier-workspace.md)) — complete; operable register before report UX dominates  
**Unlocks:** dependable close control, cash and standalone-card accountability, first operational and historical report pack; later accounting exports remain deferred  
**Governing docs:** [reporting-and-reconciliation](../../domains/reporting-and-reconciliation.md); [ADR-0008](../../adr/0008-immutable-pos-transactions.md); [ADR-0010](../../adr/0010-business-days-sessions-and-z-reports.md); [ADR-0011](../../adr/0011-permissions-authority-and-approvals.md); [ADR-0012](../../adr/0012-stored-value-ledger.md); [ADR-0013](../../adr/0013-govern-quantity-tracked-inventory-cost.md); [ADR-0016](../../adr/0016-treat-standalone-credit-card-activity.md); [architectural-locks](../architectural-locks.md); [authorization-permissions](../../domains/authorization-permissions.md)  
**Decision note (accepted):** [phase-07-reporting-and-reconciliation-v1.md](../decisions/phase-07-reporting-and-reconciliation-v1.md)  
**Source drafts (non-governing):** [phase-7-reports-ideas](../../temp_draft/phase-7-reports-ideas); [phase-7-pos-x-and-z-reports.md](../../temp_draft/phase-7-pos-x-and-z-reports.md)  
**Parked draft:** [phase-7-optional-receipt-printing.md](../../temp_draft/phase-7-optional-receipt-printing.md) — customer receipt presentation; not a Phase 7 gate

## Characterization

Phase 7 is a **reporting and close-control phase**. It consumes posted commercial, inventory, stored-value, tender, and cash facts from Phases 4–6. It does not create new sales, tender, inventory, or stored-value postings, but it does create reporting and control records such as persisted Z snapshots, close-time external card evidence, reconciliation evidence, findings, resolutions, and report audit events.

**Phase 7 should deliver:** shared report definitions; Session and Business-Day X and Z reports; atomically persisted Z snapshots on the existing close paths; reconciliation separate from close; and a first pack of historical and operational reports.

**It should not deliver:** accounting exports, processor settlement automation, BI builders, a customer-receipt product, or hardware print stacks.

This phase must **not**:

- rewrite completed POS, inventory, cash, or stored-value source rows;
- treat reconciliation as a generic balance-changing ledger;
- invent deferred capabilities ([deferred-capabilities.md](../deferred-capabilities.md));
- introduce Node.js, a JS bundler, ViewComponent, or an SPA;
- use current master data to reinterpret completed history.

## Goal

```text
posted POS / ledger / cash facts
→ live X snapshots
→ existing close workflows
   + cash count (session)
   + optional merchant-slip card total (session, when configured)
   + machine/batch card total (business day)
   + atomically persisted Z snapshots
→ later reconciliation (review persisted variances; accept / explain / link corrections)
→ first operational / historical report pack
```

Preserve:

- historical snapshots versus current operational state;
- close versus reconcile;
- internal integrity versus reconciliation variance;
- customer returns versus post-voids;
- stored-value issuance versus merchandise sales;
- received versus refunded tenders;
- merchant-slip evidence versus machine-batch evidence (distinct comparison types).

## Already shipped (preserve; do not rebuild)

These capabilities exist from Phases 4–6. Phase 7 extends them; it does not reimplement them as new features:

| Capability | Notes |
| --- | --- |
| `Pos::CloseSession` | Idempotent close; cash-enabled sessions require closing count; expected/counted/variance stored on session |
| `Pos::CalculateExpectedCash` | Read-only expected drawer position |
| Append-only `PosSessionCashCount` | Opening, closing, manager recount |
| `Pos::CloseBusinessDay` | Blocked while any session is open; idempotent replay |
| Open-transaction / unresolved-tender close guard | Session close already refuses open transactions; unresolved tenders keep transactions open |
| Completion snapshots | Product, class, department, tax, cost, tender metadata on completed activity |
| Business / reporting date (OD-001) | `reporting_date` selected at business-day open; stored explicitly |

## Reporting sources

| Report class | Primary authority |
| --- | --- |
| Historical sales, returns, tax, classifications, cost, and margin | Completed POS snapshots |
| Discounts and price-override variance | Completed POS lines, discounts, and allocations |
| Tender activity | Completed POS tenders |
| Inventory quantities and movement valuation | Inventory ledger and current stock balances |
| Stored-value history and liability | Stored-value ledger and account balance cache |
| Open ordering and receiving operations | Current purchase orders, lines, receipts, and receipt lines |
| Active and stale holds | Current reservation records |
| Cash accountability | Sessions, completed cash tenders, cash movements, counts, and business days |
| Card close evidence | Session merchant-slip totals (when configured); business-day machine/batch totals |
| Session and business-day close | Completed activity plus persisted Z-report snapshots |
| Approvals and exceptions | Approval, audit, correction, and exception records |

## Shared report principles

### Report contracts

Each report implemented in this phase must define purpose, grain, authoritative sources, time attribution, filters, dimensions, measures, sign conventions, inclusion/exclusion rules, correction treatment, expected tie-outs, permissions, print/export behavior, freshness or source cutoff, and whether it is live, recomputed, or persisted.

Shared terminology and formulas are defined once and reused.

### Commercial measures (shared)

Reports that show commercial activity use documented shared definitions for:

- gross sales;
- price-override variance;
- discounts;
- customer returns;
- post-void commercial effects;
- net sales;
- units sold / returned / reversed / net;
- permission-controlled cost and margin.

Gross sales exclude stored-value issuance. Price-override variance remains separate from discounts. Returns and post-voids remain separate measures. Totals are derived from **line activity**, not from classifying whole transactions as only sale, return, or exchange.

### Settlement bridge

Session and business-day commercial/tender sections must make the settlement bridge explicit:

```text
Net Sales
+ Net Tax
+ Stored Value Issued or Reloaded
= Transaction Total
= Net Tenders
```

### Cash tender versus drawer movement

Cash reporting retains both:

- **tender settlement** — cash applied to transactions;
- **drawer movement** — cash physically received minus refunds and change.

### Time attribution

Two related policies:

| Policy | v1 direction |
| --- | --- |
| **Business-date assignment** | Confirm OD-001 / architectural lock: `reporting_date` is selected when the business day is opened (defaults to store-local calendar date). Stored explicitly; not reconstructed from timestamps alone. |
| **Activity attribution** | Completed POS activity reports under the Business Day in which it completes. Ledger / movement reports use posting timestamp or posting date as defined by that report. Current-state reports use an explicit as-of / source cutoff. |

Store timezone and source cutoff must be visible in report metadata. Corrections report in the period in which the corrective activity completes and retain links to originals.

## X and Z report family

Use one shared section grammar across Session X, Session Z, Business-Day X, and Business-Day Z (design detail in the X/Z draft):

1. Report identity  
2. Commercial activity  
3. Tax  
4. Stored-value activity  
5. Transaction settlement  
6. Tenders  
7. Cash accountability  
8. Card close evidence (when present)  
9. Activity counts  
10. Exceptions  
11. Close or generation information  

| Report | Scope | State effect | Persistence |
| --- | --- | --- | --- |
| Session X | One open session | None | Live / recalculated |
| Session Z | One closed session | Created atomically with session close | One canonical structured snapshot |
| Business-Day X | Entire open business day | None | Live / recalculated |
| Business-Day Z | Entire closed business day | Created atomically with business-day close | One canonical structured snapshot consolidating Session Zs |

Standard cashier-facing X/Z omit COGS, gross margin, and unit costs. Manager views may add them under cost/margin permissions.

### X-report cash visibility (accepted)

Respect blind-count configuration when present. A cashier-facing Session X may hide expected cash; users with cash-review authority may see it. Until blind-count configuration exists, default to showing expected cash on X for users who can view cash reports. **Z always retains** expected, counted, and variance regardless of X display restrictions.

### Z numbering model

- Separate **store-scoped** sequences for Session Z and Business-Day Z.
- Each number is unique within its own namespace, never reused (same durability expectation as receipt numbers).
- Formatting (zero-padding, labels) is presentation only.
- Keep any session operating / display number distinct from the Session Z number.

### Business-Day Z derivation

- Business-Day Z **consolidates the canonical persisted Session Z snapshots**, retaining each session breakdown (ADR-0010).
- Persisted Day Z commercial/tender/cash section totals are that consolidation — not an independently recalculated alternate total set.
- Close still **validates** the roll-up against underlying completed activity included in the day. Mismatch is a close-blocking integrity failure.
- Day Z also carries business-day-level card machine/batch evidence collected at day close.

### Z snapshot requirements

Each canonical Z snapshot retains at least:

- report scope and source session or business day;
- business date;
- Z number;
- `source_cutoff_at`;
- `report_definition_version`;
- `generated_at` and `generated_by`;
- structured totals and section data;
- session breakdown for business-day Z;
- close-time cash and card evidence figures applicable to that scope.

**Atomicity and idempotency:** Z number and snapshot are created in the same successful close transaction. Failed or retried close must not consume another Z number. Repeated close submission remains idempotent and returns the existing canonical snapshot. A session or business day cannot be considered successfully closed without its required Z snapshot once Phase 7 close extension lands.

**Reprint:** render the original structured snapshot using its retained definition version and historical labels, without querying current master data for measures or attribution. Require historical and numerical equivalence; do not promise byte-identical browser HTML unless a rendered artifact is explicitly retained.

### Pre-Phase-7 closed records

Already-closed Sessions and Business Days from before Phase 7 Z persistence are treated as **legacy unsnapshotted** records (or discarded as development data). Do **not** silently backfill Z numbers/snapshots. Any explicit backfill tool, if ever needed, must mark snapshots as generated after the original close.

## Integrity severity

### Close-blocking invariants

These prevent the relevant close (computed over completed activity included in the Z, inside the same close transaction as snapshot persistence):

- an open session exists (business-day close);
- an open transaction exists on the session (already enforced; preserve);
- completed tender net does not equal completed transaction net for included activity;
- Session Z totals do not equal the completed activity included in that session;
- Business-Day Z totals (Session Z consolidation) do not tie to included completed activity;
- required close-time evidence for the scope is missing **and** no authorized `evidence_unavailable` exception is recorded (cash count; session merchant-slip when grain=`session` and card tenders exist; business-day machine/batch when card tenders exist for the day);
- a required Z snapshot cannot be persisted.

### Reportable integrity exceptions

Visible and escalated, but **not** automatic POS close blockers:

- stock balance versus inventory ledger mismatch (where a complete ledger history or explicit opening baseline exists);
- stored-value cache versus ledger mismatch;
- missing historical snapshot data;
- missing cost;
- incomplete imported ledger history;
- other cross-domain diagnostic failures.

Internal consistency remains distinct from reconciliation. An internal mismatch must not be cleared merely by accepting a reconciliation variance.

## MVP operating profile

**Extensible model underneath; narrow default on top.** Accepted detail: [phase-07-reporting-and-reconciliation-v1.md](../decisions/phase-07-reporting-and-reconciliation-v1.md).

New stores default to `card_reconciliation_grain = business_day`. The ordinary store experiences:

```text
SESSION CLOSE
  Count drawer → close (no card prompt)
  → offer [Reconcile session now] or continue (session cash recon still required before day recon finalizes)

BUSINESS-DAY CLOSE
  Enter one terminal batch net total → close (+ Business-Day Z)

DAY RECONCILIATION
  Manager queue: pending session recons (if any) → day card/cash expected vs observed
  → [Reconcile now] | [Review later]
```

**Operator navigation (7b–7d):** product rules require configured session reconciliation before business-day reconciliation can finalize. Implementation must make that pending step obvious — either a **Reconcile session now** prompt after each session close, a manager queue during day reconciliation, or both. This is navigation UX, not an open business rule.

Session-grain card reconciliation, multi-terminal rows, and received/refunded detail are optional progressive capabilities — not the operator’s default vocabulary.

## Card reconciliation grain and evidence

Store-level policy (simple store column or equivalent for v1; need not wait on full OD-009):

```text
card_reconciliation_grain = session | business_day   # default: business_day
```

| Value | Session close | Business-day close |
| --- | --- | --- |
| `business_day` | No merchant-slip prompt | Collect machine/batch card evidence when the day has card tenders |
| `session` | Collect merchant-slip evidence when the session has card tenders | Still collect machine/batch evidence when the day has card tenders |

**Close collects; Z reports; reconcile reviews.**

### Evidence cardinality and precision

- One scope may contain **one or more** evidence rows (normally by terminal or batch reference).
- Each row has precision `net_only` or `received_and_refunded`.
- `net_only`: observed net only — do not invent received/refunded splits (MVP default for machine batch).
- `received_and_refunded`: store both sides; net is derived; optional counts may be retained.
- MVP UI: one row — batch/net total + optional reference. “Add another terminal/batch” and received/refunded fields are progressive.
- Comparisons use the row’s precision. ShelfStack received and refunded tenders remain separately reportable in history regardless of evidence precision.
- Merchant-slip and machine-batch are distinct comparison types.

### Missing evidence (`evidence_unavailable`)

Missing required close-time evidence **blocks close by default**.

An authorized `evidence_unavailable` exception may permit close **without fabricating an observed amount**: actor, reason, timestamp, optional terminal/batch applicability; second-user approval only when policy/thresholds require it. Z shows the exception. Comparisons may carry an unavailable observed value. Reconciliation must later enter evidence or accept the exception; day recon cannot finalize while a required day card comparison remains unresolved `evidence_unavailable` unless an authorized accept-exception resolution exists.

Processor settlement automation, chargebacks, and integrated payment batch matching remain deferred.

## Reconciliation model

Close and reconciliation remain separate (ADR-0010). A session or business day may close with a documented cash and/or card variance and be reconciled later.

Closing cash variance is calculated and persisted during close. Card evidence variances (or `evidence_unavailable`) are likewise persisted at close when those prompts apply. Reconciliation later reviews and resolves those persisted results; it does not create the original close variance.

Phase 7 does **not** introduce a generic balance-changing reconciliation adjustment. Model separately:

```text
reconciliation
├── comparisons
│   ├── expected amount (ShelfStack)
│   ├── observed amount | unavailable
│   ├── variance (when observed is numeric)
│   └── external reference
├── findings
│   ├── reason / category
│   └── explanation
└── resolution
    ├── explained_no_correction
    ├── accepted_variance
    ├── linked_domain_correction
    └── unresolved
```

When an operational balance requires correction, resolution uses the owning domain’s correction mechanism and may be linked from the reconciliation record.

### Reconciliation finalization and mutability

- One canonical reconciliation per Session or Business Day.
- **Close never automatically marks a session or day reconciled**, including exact (zero-variance) matches.
- UI may offer one-action **Reconcile now** after close; it remains a separate audited finalize action.
- Comparisons and findings may be assembled in draft (after operational close).
- Finalization records `reconciled_at` / `reconciled_by`.
- After finalization, evidence and resolutions are immutable or corrected only through append-only superseding records.

### Variance acceptance authority

| Result | MVP behavior |
| --- | --- |
| Exact match | User with reconcile permission may finalize |
| Nonzero within configured authority | Same user may explain and accept (cash-style numeric authority; card analogous when configured) |
| Above authority | Another authorized user required (ADR-0011); self-approval needs distinct elevated permission + re-auth |
| Evidence unavailable | Reason required; unresolved or authorized accept-exception — never invent $0 observed |

Close may persist nonzero variance without resolving it. Stores without configured thresholds fail closed for accepting differences while still allowing close with evidence or `evidence_unavailable`.

### Reconciliation hierarchy (v1)

- A session may be reconciled only after it closes.
- Session requirements: cash for cash-enabled; session card only when grain=`session`.
- A business day may be reconciled only after it closes and every included session with configured requirements is reconciled or explicitly excepted.
- Business-day reconciliation owns the machine/batch card comparison when the day has card tenders.
- Card-only sessions follow the card grain (no cash path).
- No reopen of a reconciled session or business day in v1.

## In scope

| Area | Include |
| --- | --- |
| Report contracts | Shared measures, signs, grain, time attribution, source cutoff, live vs persisted |
| Session X / Z | Shared grammar; extend existing session close for atomic Z; optional merchant-slip card total |
| Business-Day X / Z | Session Z consolidation; extend existing business-day close for atomic Z; machine/batch card total |
| Store card grain | `card_reconciliation_grain` session vs business_day |
| Z persistence | Structured snapshot + definition version + Z number; reprint from snapshot |
| Reconciliation | Post-close session and business-day; review persisted cash and card variances |
| Reconciliation records | Comparisons, findings, resolutions; link-only to domain corrections |
| First report pack | Commercial activity; tender; tax by component; current stock + movements; open PO / on order; SV liability |
| Permissions | Seed accepted `reporting.*` keys from the permission catalog |
| Presentation | On-screen reports; browser / `@media print` for all four X/Z; CSV for tabular pack |
| Core hardening | Close-blocking tie-outs; reportable integrity surfaces; authz; audit of Z generation and reconciliation |

### Commercial activity report (first pack)

Gross sales, price-override variance, discounts, customer returns, post-voids, net sales, units, and permission-controlled cost/margin — all from completed snapshots.

### Current stock report (first pack)

On hand, reserved, unavailable, available, and on order, plus ledger movements. Balance-to-ledger checks apply where a complete ledger history or explicit opening baseline exists.

## Out of scope

| Exclude | Why |
| --- | --- |
| Accounting journals / export batches | Deferred |
| Processor settlement, chargebacks, automated batch match | Deferred / needs integrated payments |
| Generic report builder / BI dashboards | Deferred |
| Customer receipt template system, gift receipt, return QR tokens | Later; not reporting core |
| ESC/POS / printer queues / hardware profiles | Deferred |
| Editing persisted Z; destructive reconciliation | Forbidden |
| Replacing domain corrections with generic recon balance mutation | Forbidden |
| Reopen of reconciled day/session | No for v1 |
| Silent backfill of Z onto pre-Phase-7 closes | Forbidden; legacy unsnapshotted or explicit marked backfill only |
| Dated / arbitrary historical inventory valuation beyond ledger capability | Limited / open |
| Rewriting history under current catalog or department assignments | Forbidden |

### Unrelated open work

The following remain outside Phase 7 and must not be pulled into its PRs:

- OD-009, OD-010, and OD-013 (except a minimal store field for `card_reconciliation_grain` without resolving OD-009 broadly)
- seeding `inventory.receipt.correct` before a posted-receipt correction workflow is accepted
- removing the Phase 6 OD-014 interim post-settlement post-void block without the accepted correction algorithm
- return-containing post-void until append-only Product Request fulfilment restoration lands

## Delivery gates

Gates may land as sequential short-lived PRs. Prefer finishing 7a before deep UI polish. **7e may trail 7b–7d** once shared definitions exist. Optional extensions are not numbered gates.

| Gate | Focus | Core? |
| --- | --- | --- |
| **7a** | **Contracts & schema locks** — accepted in [decision note](../decisions/phase-07-reporting-and-reconciliation-v1.md); schema sketches for Z, multi-row directional card evidence, `evidence_unavailable`, recon records; seed `reporting.*` permissions | Yes |
| **7b** | **Session X / Z** — MVP: cash count only at session close; live Session X; extend `CloseSession` for atomic Session Z; optional post-close **Reconcile session now**; merchant-slip path only when grain=`session`; enforce `pos.session.close`; settlement bridge | Yes |
| **7c** | **Business-Day X / Z** — MVP: one machine/batch net total (+ optional ref) at day close; Day Z consolidates Session Zs; `evidence_unavailable` path; enforce `pos.business_day.close` | Yes |
| **7d** | **Reconciliation** — never auto at close; session then day hierarchy with manager queue for pending sessions; Reconcile now / Review later; exact-match one-click finalize; authority-bounded variance accept | Yes |
| **7e** | **First report pack** — commercial activity; tender received/refunded; tax by component; current stock + ledger movements; open PO / on order; SV liability roll-forward; CSV export | Yes for full phase; may trail 7b–7d |

### Optional extensions (not a gate)

- Expanded approval / exception report pack (post-voids, overrides, no-sales, variances, `void_required` history)
- Optional department breakdowns on thermal or compact prints
- Manager cost / margin views beyond the first pack minimum
- Additional presentation refinements

Do **not** absorb customer-receipt product design or hardware printing into these extensions.

## Decisions (accepted in 7a)

Full text: [phase-07-reporting-and-reconciliation-v1.md](../decisions/phase-07-reporting-and-reconciliation-v1.md).

| # | Decision | Accepted direction (summary) |
| ---: | --- | --- |
| 1 | v1 required reports | X/Z + cash/card recon + first report pack |
| 2 | Print / export | Browser print all four X/Z; CSV tabular; no hardware |
| 3 | Card grain and evidence | Default `business_day`; multi-row evidence; `net_only` \| `received_and_refunded`; MVP one net batch total |
| 4 | Reconciliation taxonomy | Comparisons / findings / resolutions; no generic balance-changing adjustment |
| 5 | Hierarchy + missing evidence | Configured session requirements; `evidence_unavailable` without inventing amounts |
| 6 | Reopen after reconcile | No for v1 |
| 7 | Permission ownership | `reporting.*` for recon/views; close stays `pos.*.close`; use `record_reconciliation_resolution` |
| 8 | Integrity severity | Close-blocking vs reportable split |
| 9 | Z atomicity / idempotency | Number + snapshot with close |
| 10 | Time attribution | OD-001 confirmed; activity by completion day / posting / as-of |
| 11 | Classification views | Historical snapshots authoritative for core |
| 12 | Z numbering | Separate store-scoped Session and Business-Day sequences |
| 13 | Day Z derivation | Consolidate Session Zs; validate vs activity |
| 14 | Reprint fidelity | Structured snapshot; historical/numerical equivalence |
| 15 | Finalization | Never auto-reconcile at close; one-click Reconcile now allowed as separate action |
| 16 | Variance authority | Exact match / within threshold / above threshold / evidence unavailable (cash-style) |
| 17 | Pre-Phase-7 closes | Legacy unsnapshotted; no silent backfill |

**MVP profile + pre-7b X cash visibility** are part of the same decision note.

## Likely supporting records

Schema design should consider records equivalent to:

- store `card_reconciliation_grain` (default `business_day`);
- store-scoped Session Z and Business-Day Z sequences;
- persisted Session Z and Business-Day Z snapshots;
- card evidence rows (precision, received/refunded/net, optional counts, terminal/batch ref) and/or `evidence_unavailable` exceptions;
- reconciliation headers (one canonical per session/day);
- reconciliation comparisons (observed may be unavailable), findings, and resolutions;
- links from resolutions to domain-owned corrective records;
- report / close / reconciliation audit events.

Exact table names remain implementation detail. A generic reconciliation record must not act as an alternative financial, inventory, cash, or stored-value ledger.

## Permissions

Canonical rows: [authorization-permissions.md](../../domains/authorization-permissions.md) (`reporting.*`).

Close remains `pos.session.close` / `pos.business_day.close`. Reconcile and resolution keys are under `reporting.*` (decision 7). Cost, margin, and audit access remain more restricted than ordinary sales reporting.

**7b/7c:** extend close services only with service-boundary enforcement of the existing close permissions (gap called out in [business-day-close.md](../../workflows/business-day-close.md)).

## Exit criteria

### Core gate (7a–7d) — close and reconciliation operable

- [ ] Shared definitions documented and used: gross sales, price-override variance, discounts, returns, post-voids, net sales, tax, SV issuance/reload, tender received/refunded/net, settlement bridge
- [ ] Time attribution and source cutoff are defined per report class and visible in report metadata; OD-001 business-date policy confirmed
- [ ] New stores default to `card_reconciliation_grain = business_day`; MVP session close has no card prompt
- [ ] Session X is live, recalculated, and does not close, number, or reconcile; X cash visibility respects blind-count rules when configured
- [ ] Successful session close atomically assigns Session Z number and persists one canonical structured Z snapshot
- [ ] When grain=`session` and card tenders exist, session close requires merchant-slip evidence or `evidence_unavailable`
- [ ] Failed or retried session close does not consume another Z number; repeated close is idempotent
- [ ] A session cannot be successfully closed without its required Z snapshot
- [ ] Session Z cash path retains expected/counted/variance; recounts append; cashier view omits cost/margin
- [ ] Business-Day X retains session breakdown
- [ ] Successful business-day close atomically assigns Business-Day Z number and persists consolidation of Session Z snapshots
- [ ] When the day has card tenders, day close accepts machine/batch evidence (`net_only` MVP) or `evidence_unavailable` — never invents $0 observed
- [ ] Card evidence schema supports multiple rows and `received_and_refunded` precision; MVP UI is one net row
- [ ] Day Z totals are Session Z consolidation; close validates roll-up against completed activity
- [ ] Failed or retried business-day close does not consume another Z number; repeated close is idempotent
- [ ] A business day cannot be successfully closed without its required Z snapshot
- [ ] Business day still cannot close while a session remains open (preserved)
- [ ] Defined close-blocking tie-out failures prevent close; broader integrity anomalies surface as exceptions without automatically blocking close
- [ ] Close never auto-reconciles; Reconcile now / Review later remains a separate audited action (including exact matches)
- [ ] One canonical reconciliation per session/day; finalization is immutable or append-only superseding
- [ ] Reconciliation reviews persisted close results per hierarchy and grain; unavailable observed values are supported
- [ ] Comparisons, findings, and resolutions do not alter POS, tenders, ledgers, counts, or Z rows
- [ ] Operational correction from reconciliation uses owning-domain services and is linkable from the reconciliation record
- [ ] Internal tie-out failures cannot be cleared only by accepting a reconciliation variance
- [ ] Variance acceptance follows cash-style authority (exact / within / above / evidence unavailable)
- [ ] Pre-Phase-7 closed records remain legacy unsnapshotted (no silent backfill)
- [ ] `reporting.*` permissions seeded; close and reconcile surfaces enforce authorization at the service boundary
- [ ] Browser print works for Session X, Session Z, Business-Day X, and Business-Day Z without a hardware-specific stack
- [ ] Reprint of a Z report reproduces historical and numerical equivalence from the structured snapshot without current master data

### Full phase (adds 7e)

- [ ] Commercial activity report unchanged after product, department, merchandise class, tax category, or description rename
- [ ] Returns and post-voids appear in the business day / period in which the corrective activity completes and retain links to originals
- [ ] Received and refunded tenders are separately reportable; completed tender net ties to completed transaction net
- [ ] Session totals tie to included completed activity; business-day totals tie to included sessions
- [ ] Current stock reports on hand, reserved, unavailable, available, and on order; balance↔ledger mismatch is detectable where a complete ledger history or explicit opening baseline exists
- [ ] Historical margin uses completed POS cost snapshots, not current inventory cost
- [ ] Open-PO report reads current purchasing records
- [ ] Stored-value liability roll-forward ties to ledger activity; cache↔ledger mismatch is detectable
- [ ] Core tabular reports export CSV without creating accounting entries
- [ ] Cost and margin reports require their designated permissions

### Explicitly not exit criteria

- Customer receipt CSS product, gift receipt, or return-token system
- Processor batch matching or chargebacks
- Accounting export
- Reopening reconciled periods
- Silent Z backfill of pre-Phase-7 closes
- “Business day cannot close while session open” as *new* work (already shipped)

## Testing expectations

Proportionate coverage for:

- Z atomicity and idempotency on session and business-day close;
- Session Z vs Business-Day Z sequence isolation;
- Day Z consolidation from Session Zs plus activity validation;
- MVP `business_day` path (no session card prompt; one day net batch total);
- `card_reconciliation_grain` session path and multi-row / received_and_refunded progressive detail;
- `evidence_unavailable` close without invented observed amounts;
- close never auto-reconciles; exact-match finalize is a separate action;
- close-blocking versus reportable integrity classification;
- X non-mutation and X cash visibility rules;
- Z reprint from snapshot after master-data rename;
- cash and card variance persistence at close and later reconciliation review;
- authority-bounded variance accept vs over-threshold approval;
- reconciliation finalization immutability / append-only supersede;
- resolution linking to domain corrections without mutating sources;
- permission denials on cost/margin and reconcile actions;
- CSV export of first-pack tabular reports.

Prefer service and request tests for close/recon paths; system tests for the MVP close → Z → Reconcile now path.

## Implementation order

1. 7a accepted — keep schema sketches and seeded `reporting.*` keys aligned with the decision note.
2. 7b — Session X and Session Z on `CloseSession` (MVP cash only; enforce close permission).
3. 7c — Business-Day X and Business-Day Z on `CloseBusinessDay` (net batch total or `evidence_unavailable`).
4. 7d — Reconciliation (Reconcile now / Review later).
5. 7e — First report pack (may overlap after 7a).
6. Optional extensions only if schedule allows; do not block phase exit.

## Related

- [../roadmap.md](../roadmap.md)
- [../current-phase.md](../current-phase.md)
- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
- [phase-05-supply-and-demand.md](phase-05-supply-and-demand.md)
- [phase-06-corrections-and-stored-value.md](phase-06-corrections-and-stored-value.md)
- [phase-06.5-cashier-workspace.md](phase-06.5-cashier-workspace.md)
- [../../workflows/business-day-close.md](../../workflows/business-day-close.md)
- [../../domains/point-of-sale.md](../../domains/point-of-sale.md)
