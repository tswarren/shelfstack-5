# Current Phase

**Active delivery phase:** Phase 8 — Catalog refinement & enrichment  
**Status:** Phase 7 complete on `main`; Phase 8 ready for implementation — not started; first target Gate 8a  
**Phase 7 merge:** `d27d6668312b19d0012fd8d370011c966838f895` (PR [#62](https://github.com/tswarren/shelfstack-5/pull/62)); core gate 7a–7d accepted; **7e partial** ([#94](https://github.com/tswarren/shelfstack-5/issues/94))  
**Phase 6.5 merge:** `bd7fb9d35469027a60c9d3277744fda0a0ed06d9` (PR [#54](https://github.com/tswarren/shelfstack-5/pull/54)); walkthrough accepted 2026-07-23  
**Phase 6 merge:** `853ae3b7a31b03960935bb14d8761b3fd19a0258` (PR [#39](https://github.com/tswarren/shelfstack-5/pull/39); [#36](https://github.com/tswarren/shelfstack-5/issues/36) closed)  
**Phase 5 merge:** `2e3e1196ec923b20a667f52b8ae79bd86c0b5c8b` (PR #34)  
**Phase 4g merge:** `c51dcca823e4476b7f0f62441301d451e83307b2` (PR #31)  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Phase 7 plan (complete core):** [phases/phase-07-reporting-and-reconciliation.md](phases/phase-07-reporting-and-reconciliation.md)  
**Decision note (Phase 7):** [phase-07-reporting-and-reconciliation-v1.md](decisions/phase-07-reporting-and-reconciliation-v1.md)  
**Phase 8 plan:** [phases/phase-08-catalog-refinement-and-enrichment.md](phases/phase-08-catalog-refinement-and-enrichment.md)  
**Decision note (Phase 8):** [phase-08-catalog-refinement-and-enrichment-v1.md](decisions/phase-08-catalog-refinement-and-enrichment-v1.md) (OD-P8-01…10 accepted / deferred as noted)  
**Source draft (superseded):** [phase-8-catalog-refinement-ideas.md](../temp_draft/phase-8-catalog-refinement-ideas.md)  

**Phase 6.5 plan (complete):** [phases/phase-06.5-cashier-workspace.md](phases/phase-06.5-cashier-workspace.md)  
**Phase 6 plan (complete):** [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md)  
**Decision notes (Phase 6):** [post-void eligibility](decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md); [inventory correction / OD-014](decisions/phase-06-inventory-correction-and-od-014.md); [stored-value v1 policy](decisions/phase-06-stored-value-v1-operating-policy.md)

## Immediate next work

1. Start Phase 8 Gate 8a (shared linking controls); then 8b–8c bibliographic/provider foundation and create-from-ISBN; keep enrichment ahead of multi-variant (Phase 8.5).
2. Optional short ops-hardening before or beside Phase 8 start: keyboard/scanner [#51](https://github.com/tswarren/shelfstack-5/issues/51); control-master admin CRUD / store settings UI (DWR-018/019).
3. Phase 7 follow-ups remain deferred (`phase-7` + `deferred`); canonical list in [deferred-work-register.md](deferred-work-register.md):
   - Linked domain correction resolutions — [#89](https://github.com/tswarren/shelfstack-5/issues/89)
   - Resolution superseding / post-finalization policy — [#90](https://github.com/tswarren/shelfstack-5/issues/90)
   - Session card grain / merchant-slip close — [#91](https://github.com/tswarren/shelfstack-5/issues/91)
   - Directional / multi-terminal card evidence — [#92](https://github.com/tswarren/shelfstack-5/issues/92)
   - Org-scoped stored-value liability & cache integrity — [#93](https://github.com/tswarren/shelfstack-5/issues/93)
   - Complete Phase 7e report pack — [#94](https://github.com/tswarren/shelfstack-5/issues/94)
4. Keep posted-receipt correction (`inventory.receipt.correct`) unseeded until a correction workflow is accepted.
5. Retain OD-014 interim post-void block until a full correction algorithm PR is accepted.
6. Return-containing post-void remains blocked until append-only Product Request fulfilment restoration lands.
7. Keep [architectural-locks.md](architectural-locks.md) binding; track remaining open items in [open-decisions.md](open-decisions.md) (OD-009, OD-010, OD-013 remain open/deferred). Do not close OD-010 when adding aggregate `unavailable_delta`.
8. Do not pull customer-receipt product design or hardware printing into Phase 8 (parked draft only).

## Completed recently

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
