# Current Phase

**Active delivery phase:** none (between phases)  
**Status:** Phase 8 **closed** — Must gates 8a–8d complete and accepted ([#95](https://github.com/tswarren/shelfstack-5/issues/95)–[#98](https://github.com/tswarren/shelfstack-5/issues/98); Gate 8d merge PR [#118](https://github.com/tswarren/shelfstack-5/pull/118) at `befe351`). Should/Nice gates 8e–8g deferred to [deferred-work-register.md](deferred-work-register.md) (DWR-022 / DWR-023 / DWR-027 / DWR-065).  

**Phase 8 plan (complete core):** [phases/phase-08-catalog-refinement-and-enrichment.md](phases/phase-08-catalog-refinement-and-enrichment.md)  
**Decision note (Phase 8):** [phase-08-catalog-refinement-and-enrichment-v1.md](decisions/phase-08-catalog-refinement-and-enrichment-v1.md) (OD-P8-01…10 accepted / deferred as noted)  
**Phase 8 issues:** 8a–8d [#95](https://github.com/tswarren/shelfstack-5/issues/95)–[#98](https://github.com/tswarren/shelfstack-5/issues/98) (done); deferred 8e [#99](https://github.com/tswarren/shelfstack-5/issues/99), 8f [#100](https://github.com/tswarren/shelfstack-5/issues/100), 8g [#101](https://github.com/tswarren/shelfstack-5/issues/101)  

**Phase 7 merge:** `d27d6668312b19d0012fd8d370011c966838f895` (PR [#62](https://github.com/tswarren/shelfstack-5/pull/62)); core gate 7a–7d accepted; **7e partial** ([#94](https://github.com/tswarren/shelfstack-5/issues/94))  
**Phase 6.5 merge:** `bd7fb9d35469027a60c9d3277744fda0a0ed06d9` (PR [#54](https://github.com/tswarren/shelfstack-5/pull/54)); walkthrough accepted 2026-07-23  
**Phase 6 merge:** `853ae3b7a31b03960935bb14d8761b3fd19a0258` (PR [#39](https://github.com/tswarren/shelfstack-5/pull/39); [#36](https://github.com/tswarren/shelfstack-5/issues/36) closed)  
**Phase 5 merge:** `2e3e1196ec923b20a667f52b8ae79bd86c0b5c8b` (PR #34)  
**Phase 4g merge:** `c51dcca823e4476b7f0f62441301d451e83307b2` (PR #31)  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Phase 7 plan (complete core):** [phases/phase-07-reporting-and-reconciliation.md](phases/phase-07-reporting-and-reconciliation.md)  
**Decision note (Phase 7):** [phase-07-reporting-and-reconciliation-v1.md](decisions/phase-07-reporting-and-reconciliation-v1.md)  
**Source draft (superseded):** [phase-8-catalog-refinement-ideas.md](../temp_draft/phase-8-catalog-refinement-ideas.md)  

**Phase 6.5 plan (complete):** [phases/phase-06.5-cashier-workspace.md](phases/phase-06.5-cashier-workspace.md)  
**Phase 6 plan (complete):** [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md)  
**Decision notes (Phase 6):** [post-void eligibility](decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md); [inventory correction / OD-014](decisions/phase-06-inventory-correction-and-od-014.md); [stored-value v1 policy](decisions/phase-06-stored-value-v1-operating-policy.md)

## Immediate next work

No new delivery phase is opened yet. Prefer small ops / carry-forward work. Phase 8.5 (multi-variant) stays **unscheduled** (DWR-021).

1. Optional ops hardening: keyboard/scanner [#51](https://github.com/tswarren/shelfstack-5/issues/51); control-master admin CRUD / store settings UI (DWR-018/019); PO/receipt nested line pickers (DWR-020).
2. Phase 8 deferred Should/Nice gates remain register-tracked until pulled back: vendor-source linking (DWR-065 / [#99](https://github.com/tswarren/shelfstack-5/issues/99)); enrich-existing (DWR-022 / [#100](https://github.com/tswarren/shelfstack-5/issues/100)); images/subjects/BISAC/DQ views (DWR-023/027 / [#101](https://github.com/tswarren/shelfstack-5/issues/101)).
3. Phase 8 non-blocking cleanups: DWR-028 [#116](https://github.com/tswarren/shelfstack-5/issues/116); DWR-029 [#119](https://github.com/tswarren/shelfstack-5/issues/119); DWR-064 [#120](https://github.com/tswarren/shelfstack-5/issues/120).
4. Phase 7 follow-ups remain deferred (`phase-7` + `deferred`); canonical list in [deferred-work-register.md](deferred-work-register.md):
   - Linked domain correction resolutions — [#89](https://github.com/tswarren/shelfstack-5/issues/89)
   - Resolution superseding / post-finalization policy — [#90](https://github.com/tswarren/shelfstack-5/issues/90)
   - Session card grain / merchant-slip close — [#91](https://github.com/tswarren/shelfstack-5/issues/91)
   - Directional / multi-terminal card evidence — [#92](https://github.com/tswarren/shelfstack-5/issues/92)
   - Org-scoped stored-value liability & cache integrity — [#93](https://github.com/tswarren/shelfstack-5/issues/93)
   - Complete Phase 7e report pack — [#94](https://github.com/tswarren/shelfstack-5/issues/94)
5. Keep posted-receipt correction (`inventory.receipt.correct`) unseeded until a correction workflow is accepted.
6. Retain OD-014 interim post-void block until a full correction algorithm PR is accepted.
7. Return-containing post-void remains blocked until append-only Product Request fulfilment restoration lands.
8. Keep [architectural-locks.md](architectural-locks.md) binding; track remaining open items in [open-decisions.md](open-decisions.md) (OD-009, OD-010, OD-013 remain open/deferred). Do not close OD-010 when adding aggregate `unavailable_delta`.
9. Do not pull customer-receipt product design or hardware printing into the next phase (parked draft only).
10. Do not open Phase 8.5 / multi-variant (DWR-021) until explicitly scheduled; cross-domain packet still required before any schema unlock.

## Completed recently

- Phase 8 core closed: Must gates 8a–8d accepted; Should/Nice 8e–8g moved to the Deferred Work Register.
- Gate 8d product summary hub merged to `main` (PR [#118](https://github.com/tswarren/shelfstack-5/pull/118); [#98](https://github.com/tswarren/shelfstack-5/issues/98)) — selected-store framing, tracking-mode stock, permission-gated datasets, org-wide vendor sources; OD-P8-10 language/date revision included.
- Gate 8c create-from-ISBN merged to `main` (PRs [#105](https://github.com/tswarren/shelfstack-5/pull/105), [#106](https://github.com/tswarren/shelfstack-5/pull/106); closes [#97](https://github.com/tswarren/shelfstack-5/issues/97)). Review hardening: accept binds immutable provenance via signed `Catalog::ProductImportPreviewToken` (30m TTL, org+actor binding); variant regular price never persisted from this path; ISBN accept/existing honor Product Request `return_to` ([#112](https://github.com/tswarren/shelfstack-5/pull/112)).
- Gate 8b bibliographic schema, Creators, and ISBNdb/Google Books adapters merged to `main` (PRs [#103](https://github.com/tswarren/shelfstack-5/pull/103), [#104](https://github.com/tswarren/shelfstack-5/pull/104); closes [#96](https://github.com/tswarren/shelfstack-5/issues/96)).
- Gate 8a shared record-picker merged to `main` (PR [#102](https://github.com/tswarren/shelfstack-5/pull/102), closes [#95](https://github.com/tswarren/shelfstack-5/issues/95)).
- Phase 7 — Reporting and Reconciliation merged to `main` at `d27d6668312b19d0012fd8d370011c966838f895` (PR [#62](https://github.com/tswarren/shelfstack-5/pull/62)); core gate 7a–7d complete; 7e partial ([#94](https://github.com/tswarren/shelfstack-5/issues/94)).
- Deferred work organization: [deferred-work-register.md](deferred-work-register.md) + GitHub follow-ups [#89](https://github.com/tswarren/shelfstack-5/issues/89)–[#94](https://github.com/tswarren/shelfstack-5/issues/94).
- Phase 6.5 cashier workspace merged to `main` at `bd7fb9d35469027a60c9d3277744fda0a0ed06d9` (PR [#54](https://github.com/tswarren/shelfstack-5/pull/54)); walkthrough accepted 2026-07-23.
- Phase 6 merged to `main` at `853ae3b` (PR [#39](https://github.com/tswarren/shelfstack-5/pull/39); [#36](https://github.com/tswarren/shelfstack-5/issues/36) closed).
- Phase 5 — Supply and Demand merged to `main` at `2e3e119` (PR #34).

## Do not start yet

- Inventing deficit settlement beyond the accepted OD-014 Phase 5 decision, or removing the Phase 6 interim post-settlement post-void block without the accepted correction algorithm.
- Seeding `inventory.receipt.correct` before a posted-receipt correction workflow is accepted.
- Closing [OD-009](open-decisions.md), [OD-010](open-decisions.md), or [OD-013](open-decisions.md) without an accepted decision.
- Deferred capabilities in [deferred-capabilities.md](deferred-capabilities.md) (later extensions; not Phase 8 catalog work).
- PWA / offline POS as adopted architecture.
- External Inter font dependency (see deferred UX in the 4f phase plan).
- Customer receipt template system, gift receipts, ESC/POS / printer queues (parked).
- Processor settlement automation, chargebacks, or accounting export batches.
- Fat Phase 6.5 scope beyond the completed phase plan — see [phases/phase-06.5-cashier-workspace.md](phases/phase-06.5-cashier-workspace.md) out of scope.
- Pulling Phase 8 Should/Nice gates (8e–8g) back into an active phase without an explicit re-plan.
- Opening Phase 8.5 / multi-variant (DWR-021) without an explicit schedule and accepted cross-domain packet.

## Pointers

- Carry-forward backlog: [deferred-work-register.md](deferred-work-register.md)
- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Testing: [testing.md](testing.md), [testing/test-review-2026-07-19.md](testing/test-review-2026-07-19.md)
- Services: [service-catalog.md](service-catalog.md)
- Phase 5 plan (complete): [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)
- Phase 6 plan (complete): [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md)
- Phase 6.5 plan (complete): [phases/phase-06.5-cashier-workspace.md](phases/phase-06.5-cashier-workspace.md)
- Phase 7 plan (complete core): [phases/phase-07-reporting-and-reconciliation.md](phases/phase-07-reporting-and-reconciliation.md)
- Phase 8 plan (complete core): [phases/phase-08-catalog-refinement-and-enrichment.md](phases/phase-08-catalog-refinement-and-enrichment.md)
