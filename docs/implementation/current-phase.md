# Current Phase

**Active delivery phase:** Phase 6 — Corrections and Stored Value (planning)  
**Status:** Phase 5 merged to `main`; Phase 6 not started — plan from [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md) without inventing unresolved correction or stored-value details  
**Phase 5 merge:** `2e3e1196ec923b20a667f52b8ae79bd86c0b5c8b` (PR #34)  
**Phase 4g merge:** `c51dcca823e4476b7f0f62441301d451e83307b2` (PR #31)  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md)

## Immediate next work

1. Scaffold Phase 6 from ADR-0008 / ADR-0012 and the Phase 6 phase plan (post-void reversing records; stored-value accounts and append-only ledger).
2. Keep posted-receipt correction (`inventory.receipt.correct`) unseeded until a correction workflow is accepted.
3. Continue pre-production Phase 5 hardening in [#33](https://github.com/tswarren/shelfstack-5/issues/33) as needed.
4. Keep [architectural-locks.md](architectural-locks.md) binding; track remaining open items in [open-decisions.md](open-decisions.md) (OD-009, OD-010, OD-013 remain open/deferred).

## Completed recently

- Phase 5 — Supply and Demand merged to `main` at `2e3e119` (PR #34): vendors and vendor sources; purchase orders with derived `on_order`; multi-PO receipts with OD-014 deficit settlement; product-backed Product Requests; Customer Request allocations (OD-007); receipt→reservation conversion; POS fulfilment; operational `/reports` views; schema docs under `docs/schema/`.
- Phase 4a–4e (Point of Sale) and Phase 4f UX Baseline Gate merged to `main` (PR #30).
- Phase 4g test hardening merged to `main` (PR #31).

## Do not start yet

- Inventing deficit settlement beyond the accepted OD-014 Phase 5 decision.
- Seeding `inventory.receipt.correct` before a posted-receipt correction workflow is accepted.
- Closing [OD-009](open-decisions.md), [OD-010](open-decisions.md), or [OD-013](open-decisions.md) without an accepted decision.
- Deferred capabilities in [deferred-capabilities.md](deferred-capabilities.md).
- PWA / offline POS as adopted architecture.
- External Inter font dependency (see deferred UX in the 4f phase plan).
- Speculative Phase 6 tables or behaviors beyond ADR-0008 / ADR-0012 and the Phase 6 phase plan.

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Testing: [testing.md](testing.md), [testing/test-review-2026-07-19.md](testing/test-review-2026-07-19.md)
- Services: [service-catalog.md](service-catalog.md)
- Phase 5 plan (complete): [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)
