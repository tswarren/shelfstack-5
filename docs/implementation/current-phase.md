# Current Phase

**Active delivery phase:** Phase 4f close-out  
**Status:** Complete and accepted; PR #30 pending merge  
**Next:** Phase 4g test hardening  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan documents:** [phases/phase-04f-ux-baseline.md](phases/phase-04f-ux-baseline.md), [phases/phase-04g-test-hardening.md](phases/phase-04g-test-hardening.md)

## Immediate next work

1. Merge PR #30 (`phase/ux-baseline` → `main`) after walkthrough-fix validation (`bin/ci` + Docker `test:system` reported green).
2. After merge, record merge SHA on Phase 4 / 4f docs and set active phase to Phase 4g.
3. Execute Phase 4g in order: completion integrity → critical endpoint security → critical system workflows. That trio gates the first substantive Phase 5 PR.
4. Broader classification/controller/model backlog (4g-4/4g-5) may continue alongside Phase 5 after the integrity gate.
5. Keep [OD-014](open-decisions.md) full settlement/variance representation open for Phase 5; the Phase 4c interim remains accepted.
6. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

## Completed recently

- Phase 4a–4e (Point of Sale) on `main`.
- Phase 4f UX Baseline Gate: foundation → POS → catalog/inventory → admin → review/observation fixes; manual walkthrough accepted.
- Walkthrough follow-up: expected-cash formula (tendered − change − refunds) and Docker Chromium for `test:system`.

## Do not start yet

- Substantive Phase 5 migrations or domain PRs before Phase 4g integrity/security/browser gate (see [phase-04g-test-hardening.md](phases/phase-04g-test-hardening.md)).
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
