# Current Phase

**Active delivery phase:** Phase 7 — Reporting and Reconciliation  
**Status:** Planning — phase plan includes 17 working 7a decisions (card grain, slip vs machine evidence, Z numbering); 7a not yet formally locked  
**Phase 6.5 merge:** `bd7fb9d35469027a60c9d3277744fda0a0ed06d9` (PR [#54](https://github.com/tswarren/shelfstack-5/pull/54)); walkthrough accepted 2026-07-23  
**Phase 6 merge:** `853ae3b7a31b03960935bb14d8761b3fd19a0258` (PR [#39](https://github.com/tswarren/shelfstack-5/pull/39); [#36](https://github.com/tswarren/shelfstack-5/issues/36) closed)  
**Phase 5 merge:** `2e3e1196ec923b20a667f52b8ae79bd86c0b5c8b` (PR #34)  
**Phase 4g merge:** `c51dcca823e4476b7f0f62441301d451e83307b2` (PR #31)  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-07-reporting-and-reconciliation.md](phases/phase-07-reporting-and-reconciliation.md)  
**Phase 6.5 plan (complete):** [phases/phase-06.5-cashier-workspace.md](phases/phase-06.5-cashier-workspace.md)  
**Phase 6 plan (complete):** [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md)  
**Decision notes (Phase 6):** [post-void eligibility](decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md); [inventory correction / OD-014](decisions/phase-06-inventory-correction-and-od-014.md); [stored-value v1 policy](decisions/phase-06-stored-value-v1-operating-policy.md)  
**Source drafts (non-governing):** [phase-7-reports-ideas](../temp_draft/phase-7-reports-ideas); [phase-7-pos-x-and-z-reports.md](../temp_draft/phase-7-pos-x-and-z-reports.md)

## Immediate next work

1. Start Phase 7 gate **7a** — lock the 17 working decisions (especially `card_reconciliation_grain`, merchant-slip vs machine-batch evidence, Z numbering/derivation, recon finalization, permission ownership); write a Phase 7 decision note.
2. Keep posted-receipt correction (`inventory.receipt.correct`) unseeded until a correction workflow is accepted.
3. Retain OD-014 interim post-void block until a full correction algorithm PR is accepted.
4. Return-containing post-void remains blocked until append-only Product Request fulfilment restoration lands.
5. Keep [architectural-locks.md](architectural-locks.md) binding; track remaining open items in [open-decisions.md](open-decisions.md) (OD-009, OD-010, OD-013 remain open/deferred). Do not close OD-010 when adding aggregate `unavailable_delta`.
6. Do not pull customer-receipt product design or hardware printing into Phase 7 core gates (parked draft only).

## Completed recently

- Phase 7 plan revised: gates 7a–7e; store `card_reconciliation_grain`; session merchant-slip vs day machine-batch card evidence at close; Z numbering and Day Z = Session Z consolidation; recon finalization; 17 working 7a decisions.
- Phase 6.5 cashier workspace merged to `main` at `bd7fb9d35469027a60c9d3277744fda0a0ed06d9` (PR [#54](https://github.com/tswarren/shelfstack-5/pull/54)); walkthrough accepted 2026-07-23.
- Phase 6 merged to `main` at `853ae3b` (PR [#39](https://github.com/tswarren/shelfstack-5/pull/39)); [#36](https://github.com/tswarren/shelfstack-5/issues/36) closed. Operator CI validation passed on the release.
- Phase 6 card terminal recording under [ADR-0016](../adr/0016-treat-standalone-credit-card-activity.md): thin `AddCardTender` / `AddCardRefundTender` / durable `void_required` → `RecordVoidedCardTender` / `VoidCardTender` / Policy A `ApprovePostVoid` + confirmation audits before `PostVoidTransaction`; prep tables removed.
- Phase 6 #36 hardening: shared `ValidateCompletionReadiness`, corrective/hardening migration fold into create migrations.
- Phase 6 implementation: 6a post-void + unavailable ledger + `Inventory::ReverseLedgerEntry`; 6b SV accounts/ledger/adjustments; 6c gift-card issue/reload lines; 6d redeem/refund tenders; 6e SV-aware post-void with later-redemption block; OD-014 interim and return-txn post-void blocks retained.
- Phase 5 — Supply and Demand merged to `main` at `2e3e119` (PR #34).
- Phase 4a–4e (Point of Sale) and Phase 4f UX Baseline Gate merged to `main` (PR #30).
- Phase 4g test hardening merged to `main` (PR #31).

## Do not start yet

- Inventing deficit settlement beyond the accepted OD-014 Phase 5 decision, or removing the Phase 6 interim post-settlement post-void block without the accepted correction algorithm.
- Seeding `inventory.receipt.correct` before a posted-receipt correction workflow is accepted.
- Closing [OD-009](open-decisions.md), [OD-010](open-decisions.md), or [OD-013](open-decisions.md) without an accepted decision.
- Deferred capabilities in [deferred-capabilities.md](deferred-capabilities.md).
- PWA / offline POS as adopted architecture.
- External Inter font dependency (see deferred UX in the 4f phase plan).
- Customer receipt template system, gift receipts, ESC/POS / printer queues (parked; not Phase 7 core).
- Processor settlement automation, chargebacks, or accounting export batches.
- Fat Phase 6.5 scope beyond the completed phase plan — see [phases/phase-06.5-cashier-workspace.md](phases/phase-06.5-cashier-workspace.md) out of scope.

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Testing: [testing.md](testing.md), [testing/test-review-2026-07-19.md](testing/test-review-2026-07-19.md)
- Services: [service-catalog.md](service-catalog.md)
- Phase 5 plan (complete): [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)
- Phase 6 plan (complete): [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md)
- Phase 6.5 plan (complete): [phases/phase-06.5-cashier-workspace.md](phases/phase-06.5-cashier-workspace.md)
