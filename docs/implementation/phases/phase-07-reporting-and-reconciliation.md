# Phase 7 — Reporting and Reconciliation

**Status:** Not started  
**Depends on:** Phases 4–6 complete on `main` (posted POS, inventory, purchasing, stored value, corrections)  
**Preferred after:** Phase 6.5 cashier workspace ([phase-06.5-cashier-workspace.md](phase-06.5-cashier-workspace.md)) — complete; operable register before report UX dominates  
**Unlocks:** dependable close control, cash and standalone-card accountability, first operational and historical report pack; later accounting exports remain deferred  
**Governing docs:** [reporting-and-reconciliation](../../domains/reporting-and-reconciliation.md); [ADR-0008](../../adr/0008-immutable-pos-transactions.md); [ADR-0010](../../adr/0010-business-days-sessions-and-z-reports.md); [ADR-0012](../../adr/0012-stored-value-ledger.md); [ADR-0013](../../adr/0013-govern-quantity-tracked-inventory-cost.md); [ADR-0016](../../adr/0016-treat-standalone-credit-card-activity.md); [architectural-locks](../architectural-locks.md); [authorization-permissions](../../domains/authorization-permissions.md)  
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

### X-report cash visibility (settle before 7b)

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
- required close-time evidence for the scope is missing (cash count; session merchant-slip total when grain requires it and card tenders exist; business-day machine/batch total when card tenders exist for the day);
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

## Card reconciliation grain (store configuration)

Store-level policy (simple store column or equivalent for v1; need not wait on full OD-009):

```text
card_reconciliation_grain = session | business_day
```

| Value | Session close | Business-day close |
| --- | --- | --- |
| `session` | When the session has card tenders, prompt for **merchant-slip / merchant-receipt total** (cashier accountability), same interaction pattern as cash count | Prompt for **terminal / machine batch total** (device settlement) when the day has card tenders |
| `business_day` | No merchant-slip prompt | Prompt for **terminal / machine batch total** when the day has card tenders |

Default for many indie bookstores: `business_day`.

**Close collects; Z reports; reconcile reviews.** External card amounts are not invented at reconciliation time when they were required at close — reconciliation reviews the persisted close evidence and variances (parallel to cash).

Merchant-slip totals and machine-batch totals are **different comparison types**. Neither substitutes for the other. Config expresses required grain; it does not claim every terminal can isolate a session total if procedures do not support it. If grain is `session` but the store cannot produce slip totals, operators must use an authorized exception path — do not silently fabricate session card evidence.

Evidence fields for each close-time card total: amount, optional external/batch reference, optional terminal identifier, applicable range notes, entering user, timestamp.

Processor settlement automation, chargebacks, and integrated payment batch matching remain deferred.

## Reconciliation model

Close and reconciliation remain separate (ADR-0010). A session or business day may close with a documented cash and/or card variance and be reconciled later.

Closing cash variance is calculated and persisted during close. Session merchant-slip and business-day machine-batch card variances are likewise persisted at close when those prompts apply. Reconciliation later reviews and resolves those persisted variances; it does not create the original close variance.

Phase 7 does **not** introduce a generic balance-changing reconciliation adjustment. Model separately:

```text
reconciliation
├── comparisons
│   ├── expected amount (ShelfStack)
│   ├── observed amount (count, merchant slips, or machine batch)
│   ├── variance
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
- Comparisons and findings may be assembled while the reconciliation is in draft (not while the session/day is still open for operations).
- Finalization records `reconciled_at` / `reconciled_by` (and transitions status to reconciled).
- After finalization, evidence and resolutions are immutable or corrected only through append-only superseding records.

### Variance acceptance authority

- Close may persist nonzero cash or card variance without resolving it (existing cash close behavior preserved).
- **Accepting** a nonzero variance is a reconciliation act.
- Cash: reuse existing cash-variance review / authority thresholds.
- Card: nonzero accepted differences require reason and appropriate reconciliation authority (v1: any nonzero card acceptance needs recon authority + reason; no separate card threshold required unless added later).

### Reconciliation hierarchy (v1)

- A session may be reconciled only after it closes.
- Session reconciliation requirements:
  - cash-enabled sessions: cash variance review/resolution;
  - when `card_reconciliation_grain = session` and the session has card tenders: merchant-slip card comparison review/resolution;
  - when grain is `business_day`, session recon does **not** require card comparison.
- A business day may be reconciled only after it closes and every included session that has configured reconciliation requirements is reconciled or explicitly excepted.
- Business-day reconciliation owns the machine/batch card comparison when the day has card tenders (always, under both grain values).
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
| Permissions | Seed reporting view/export keys; resolve reconcile permission ownership in 7a |
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
| **7a** | **Contracts & schema locks** — shared definitions; time attribution; integrity severity; Z numbering and snapshot shapes; Day Z = Session Z consolidation + activity validation; `card_reconciliation_grain`; merchant-slip vs machine-batch comparison types; recon taxonomy and finalization; permission ownership; variance authority; legacy closed-record treatment; no reopen for v1 | Yes |
| **7b** | **Session X / Z** — live Session X (blind-count cash visibility rules); extend `CloseSession` for atomic Session Z; cash count path; merchant-slip card total when grain=`session` and card tenders exist; settlement bridge; cashier view omits cost/margin | Yes |
| **7c** | **Business-Day X / Z** — live Day X with session status; extend `CloseBusinessDay` for atomic Business-Day Z as consolidation of Session Zs; machine/batch card total when day has card tenders; close-blocking tie-outs; broader anomalies as exceptions | Yes |
| **7d** | **Reconciliation** — draft → finalize one canonical recon per session/day; review persisted cash and card variances; comparisons/findings/resolutions; link domain corrections; enforce hierarchy from grain setting | Yes |
| **7e** | **First report pack** — commercial activity; tender received/refunded; tax by component; current stock + ledger movements; open PO / on order; SV liability roll-forward; CSV export | Yes for full phase; may trail 7b–7d |

### Optional extensions (not a gate)

- Expanded approval / exception report pack (post-voids, overrides, no-sales, variances, `void_required` history)
- Optional department breakdowns on thermal or compact prints
- Manager cost / margin views beyond the first pack minimum
- Additional presentation refinements

Do **not** absorb customer-receipt product design or hardware printing into these extensions.

## Decisions to lock in 7a

Record accepted outcomes in a Phase 7 decision note and update domain / permission docs in the same change when practical. Proposed v1 directions below are the working defaults for implementation planning.

| # | Decision | Proposed / default direction |
| ---: | --- | --- |
| 1 | v1 required reports | X/Z family + cash/card recon + first report pack |
| 2 | Print / export | Browser print for all four X/Z; CSV for tabular pack; no hardware |
| 3 | Card reconciliation scope and evidence | Store `card_reconciliation_grain` = `session` \| `business_day`. Session close (when grain=`session` and card tenders exist) collects **merchant-slip total**. Business-day close (when card tenders exist) collects **machine/batch total**. Close collects; Z reports; reconcile reviews. |
| 4 | Reconciliation taxonomy | Separate comparison types, finding reasons, and resolution types; no generic balance-changing reconciliation adjustment |
| 5 | Reconciliation hierarchy | Day recon only after close and after every included session with **configured reconciliation requirements** is reconciled or explicitly excepted (cash for cash-enabled; session card only when grain=`session`; day always owns machine/batch card when applicable) |
| 6 | Reopen after reconcile | **No** for v1 |
| 7 | Permission ownership | Choose one namespace; update POS domain prose, reporting domain, and permission catalog together. Prefer `reporting.record_reconciliation_resolution` over `record_adjustment`. Do not seed overlapping keys |
| 8 | Integrity severity | Close-blocking vs reportable exceptions as in this plan |
| 9 | Z atomicity and idempotency | Number + snapshot with close; retries do not duplicate or consume numbers; successful close requires canonical snapshot |
| 10 | Time attribution | Confirm OD-001 business-date assignment; activity attribution by completion Business Day (POS), posting time/date (ledgers), explicit as-of (current-state); timezone + source cutoff in metadata |
| 11 | Current vs historical classification views | Historical snapshots authoritative; current-name views not required for core |
| 12 | Z numbering model | Separate store-scoped Session Z and Business-Day Z sequences; never reused; formatting presentation-only; distinct from any session operating number |
| 13 | Business-Day Z derivation | Consolidate persisted Session Z snapshots (retain breakdown); validate roll-up against completed activity; do not persist an independently recalculated alternate total set |
| 14 | Z snapshot and reprint fidelity | Structured snapshot authoritative; reprint from snapshot; historical/numerical equivalence; byte-identical HTML not required unless rendered artifact retained |
| 15 | Reconciliation finalization and mutability | One canonical recon per session/day; draft then finalize with `reconciled_at/by`; after finalize, immutable or append-only superseding corrections |
| 16 | Variance acceptance authority | Close may persist variance; accepting nonzero cash uses cash-variance thresholds; accepting nonzero card requires reason + recon authority |
| 17 | Pre-Phase-7 closed records | Legacy unsnapshotted (or discard dev data); no silent backfill; any backfill explicitly marked generated after original close |

**Pre-7b policy (not a separate governing OD):** X-report cash visibility respects blind-count when configured; Z always retains expected/counted/variance.

## Likely supporting records

Schema design should consider records equivalent to:

- store `card_reconciliation_grain` (or equivalent);
- store-scoped Session Z and Business-Day Z sequences;
- persisted Session Z and Business-Day Z snapshots;
- session close merchant-slip card evidence (when used);
- business-day close machine/batch card evidence;
- reconciliation headers (one canonical per session/day);
- reconciliation comparisons, findings, and resolutions;
- links from resolutions to domain-owned corrective records;
- report / close / reconciliation audit events.

Exact table names remain implementation detail. A generic reconciliation record must not act as an alternative financial, inventory, cash, or stored-value ledger.

## Permissions (direction)

View and export keys remain under `reporting.*` as listed in the reporting domain (`view_sales`, `view_tax`, `view_tenders`, `view_cash`, `view_inventory`, `view_purchasing`, `view_requests`, `view_cost`, `view_margin`, `view_stored_value`, `view_audit`, `export`), plus view keys for Session/Business-Day X and Z as needed.

Close remains on existing `pos.session.close` and `pos.business_day.close`.

Reconcile state-change keys are decided in 7a (see decision 7). Cost, margin, and audit access remain more restricted than ordinary sales reporting.

## Exit criteria

### Core gate (7a–7d) — close and reconciliation operable

- [ ] Shared definitions documented and used: gross sales, price-override variance, discounts, returns, post-voids, net sales, tax, SV issuance/reload, tender received/refunded/net, settlement bridge
- [ ] Time attribution and source cutoff are defined per report class and visible in report metadata; OD-001 business-date policy confirmed
- [ ] Store `card_reconciliation_grain` is configurable (`session` \| `business_day`) with documented close prompts
- [ ] Session X is live, recalculated, and does not close, number, or reconcile; X cash visibility respects blind-count rules when configured
- [ ] Successful session close atomically assigns Session Z number and persists one canonical structured Z snapshot
- [ ] When grain=`session` and card tenders exist, session close requires merchant-slip total; variance persists on session/Z
- [ ] Failed or retried session close does not consume another Z number; repeated close is idempotent
- [ ] A session cannot be successfully closed without its required Z snapshot
- [ ] Session Z cash path retains expected/counted/variance; recounts append; cashier view omits cost/margin
- [ ] Business-Day X retains session breakdown
- [ ] Successful business-day close atomically assigns Business-Day Z number and persists consolidation of Session Z snapshots
- [ ] When the day has card tenders, business-day close requires machine/batch total; variance persists on day/Z
- [ ] Day Z totals are Session Z consolidation; close validates roll-up against completed activity
- [ ] Failed or retried business-day close does not consume another Z number; repeated close is idempotent
- [ ] A business day cannot be successfully closed without its required Z snapshot
- [ ] Business day still cannot close while a session remains open (preserved)
- [ ] Defined close-blocking tie-out failures prevent close; broader integrity anomalies surface as exceptions without automatically blocking close
- [ ] Close and reconcile remain separate; Z is not rewritten by reconciliation
- [ ] One canonical reconciliation per session/day; finalization is immutable or append-only superseding
- [ ] Reconciliation reviews persisted close variances (cash; merchant-slip; machine/batch) per hierarchy and grain
- [ ] Comparisons, findings, and resolutions do not alter POS, tenders, ledgers, counts, or Z rows
- [ ] Operational correction from reconciliation uses owning-domain services and is linkable from the reconciliation record
- [ ] Internal tie-out failures cannot be cleared only by accepting a reconciliation variance
- [ ] Variance acceptance authority enforced for nonzero cash and card acceptances
- [ ] Pre-Phase-7 closed records remain legacy unsnapshotted (no silent backfill)
- [ ] Permission ownership decision is recorded; keys seeded; report and reconcile surfaces enforce authorization
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
- `card_reconciliation_grain` session vs business_day prompt behavior;
- merchant-slip vs machine-batch comparison types;
- close-blocking versus reportable integrity classification;
- X non-mutation and X cash visibility rules;
- Z reprint from snapshot after master-data rename;
- cash and card variance persistence at close and later reconciliation review;
- reconciliation finalization immutability / append-only supersede;
- reconciliation hierarchy under both grain settings;
- resolution linking to domain corrections without mutating sources;
- permission denials on cost/margin and reconcile actions;
- CSV export of first-pack tabular reports.

Prefer service and request tests for close/recon paths; system tests for the primary close → Z → reconcile operator path.

## Implementation order

1. Complete 7a contracts, schema shapes, grain setting, and permission ownership decision; update governing docs.
2. 7b — Session X and Session Z on `CloseSession` (cash + conditional merchant slips).
3. 7c — Business-Day X and Business-Day Z on `CloseBusinessDay` (machine/batch card total).
4. 7d — Reconciliation workflows and records.
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
