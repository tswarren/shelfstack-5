# Current Phase

**Active delivery phase:** Phase 5 — Supply and Demand  
**Status:** Ready to begin (Phase 4g gate merged)  
**Phase 4g merge:** `c51dcca823e4476b7f0f62441301d451e83307b2` (PR #31)  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)

## Immediate next work

1. Begin Phase 5 foundational purchasing / receiving / requests using Baseline page patterns. Governing plan: [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md); planning detail: [../domains/ordering-and-acquisition-planning.md](../domains/ordering-and-acquisition-planning.md); lifecycle boundaries: [phase-05-ordering-scope-and-future-lifecycle-boundaries.md](phase-05-ordering-scope-and-future-lifecycle-boundaries.md).
2. Continue residual 4g-5 backlog (exhaustive admin CRUD / remaining static models) in parallel as needed.
3. Keep [OD-014](open-decisions.md) full settlement/variance representation open for Phase 5; the Phase 4c interim remains accepted.
4. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

## Completed recently

- Phase 4a–4e (Point of Sale) and Phase 4f UX Baseline Gate merged to `main` (PR #30).
- Phase 4g test hardening merged to `main` (PR #31) — Phase 5 integrity/security/browser gate satisfied.
- Walkthrough follow-up: expected-cash formula and Docker Chromium for `test:system`.

## Do not start yet

- Inventing Phase 5 deficit settlement tables beyond the accepted OD-014 interim.
- Closing [OD-013](open-decisions.md) role/store authority defaults without an accepted decision.
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
