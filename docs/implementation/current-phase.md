# Current Phase

**Active delivery phase:** Phase 5 — Supply and Demand  
**Status:** Ready to begin (governing baseline + planning defaults locked)  
**Phase 4g merge:** `c51dcca823e4476b7f0f62441301d451e83307b2` (PR #31)  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)

## Immediate next work

1. Write and execute the Phase 5 implementation plan from [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md) (build order + planning defaults).
2. Scaffold migrations from the reconciled proforma and [ShelfStack_Schema_Reconciliation_2026-07-20.xlsx](../exports/schema/ShelfStack_Schema_Reconciliation_2026-07-20.xlsx); seed Phase 5 permissions from [authorization-permissions.md](../domains/authorization-permissions.md).
3. Continue residual 4g-5 backlog in parallel as needed.
4. Keep [architectural-locks.md](architectural-locks.md) binding; track remaining open items in [open-decisions.md](open-decisions.md).

## Completed recently

- Phase 4a–4e (Point of Sale) and Phase 4f UX Baseline Gate merged to `main` (PR #30).
- Phase 4g test hardening merged to `main` (PR #31) — Phase 5 integrity/security/browser gate satisfied.
- Phase 5 governing decisions: ADR-0015, OD-007, OD-014 settlement; domains, schema exports, and permission catalog reconciled.
- Phase 5 planning defaults locked (resolution columns, follow-up requests, allocation events, thin product path).

## Do not start yet

- Inventing deficit settlement beyond the accepted OD-014 Phase 5 decision.
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
