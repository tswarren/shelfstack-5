# Current Phase

**Active delivery phase:** Phase 6 — Corrections and Stored Value (implementation in progress; gates 6a–6e landed in working tree)  
**Status:** Phase 5 merged to `main`; Phase 6 gates 6a–6e implemented against the accepted phase plan and decision notes — harden, PR, and close exit criteria on merge  
**Phase 5 merge:** `2e3e1196ec923b20a667f52b8ae79bd86c0b5c8b` (PR #34)  
**Phase 4g merge:** `c51dcca823e4476b7f0f62441301d451e83307b2` (PR #31)  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md)  
**Decision notes:** [post-void eligibility](decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md); [inventory correction / OD-014](decisions/phase-06-inventory-correction-and-od-014.md); [stored-value v1 policy](decisions/phase-06-stored-value-v1-operating-policy.md)

## Immediate next work

1. Open PRs for Phase 6 slices (or one integrated PR) and run `./dev/rails-docker bin/ci` before merge.
2. Keep posted-receipt correction (`inventory.receipt.correct`) unseeded until a correction workflow is accepted.
3. Retain OD-014 interim post-void block until a full correction algorithm PR is accepted.
4. Return-containing post-void remains blocked until append-only Product Request fulfilment restoration lands.
5. Keep [architectural-locks.md](architectural-locks.md) binding; track remaining open items in [open-decisions.md](open-decisions.md) (OD-009, OD-010, OD-013 remain open/deferred). Do not close OD-010 when adding aggregate `unavailable_delta`.

## Completed recently

- Phase 6 implementation (working tree): 6a post-void + unavailable ledger + `Inventory::ReverseLedgerEntry`; 6b SV accounts/ledger/adjustments; 6c gift-card issue/reload lines; 6d redeem/refund tenders; 6e SV-aware post-void with later-redemption block; OD-014 interim and return-txn post-void blocks retained.
- Phase 6 planning: thin phase plan promoted; three accepted decision notes; domain and permission catalog synchronized.
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

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Testing: [testing.md](testing.md), [testing/test-review-2026-07-19.md](testing/test-review-2026-07-19.md)
- Services: [service-catalog.md](service-catalog.md)
- Phase 5 plan (complete): [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)
