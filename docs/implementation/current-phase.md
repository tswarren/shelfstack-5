# Current Phase

**Active delivery phase:** Phase 4g — Test Hardening  
**Status:** In progress on `phase/4g-test-hardening`  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-04g-test-hardening.md](phases/phase-04g-test-hardening.md)

## Immediate next work

1. Merge Phase 4g to `main` (Phase 5 gate checklist is green on this branch).
2. After merge, substantive Phase 5 PRs may land; continue residual 4g-5 backlog (exhaustive admin CRUD / remaining static models) in parallel as needed.
3. Keep [OD-014](open-decisions.md) full settlement/variance representation open for Phase 5; the Phase 4c interim remains accepted.
4. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

## Completed recently

- Phase 4a–4e (Point of Sale) and Phase 4f UX Baseline Gate merged to `main` (PR #30).
- Walkthrough follow-up: expected-cash formula and Docker Chromium for `test:system`.
- Phase 4g first pass: completion integrity (4g-1), critical endpoint security + seed-drift (4g-2), critical system workflows (4g-3), high-integrity model invariants (4g-4), and an initial 4g-5 backlog slice.

## Do not start yet

- Substantive Phase 5 migrations or domain PRs before the Phase 4g integrity/security/browser gate checklist.
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
