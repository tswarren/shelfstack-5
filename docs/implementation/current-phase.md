# Current Phase

**Active delivery phase:** Phase 4f — UX Baseline Gate  
**Status:** In progress on `phase/ux-baseline` (do not merge to `main` until the Baseline Gate is signed off)  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-04f-ux-baseline.md](phases/phase-04f-ux-baseline.md)

## Immediate next work

1. Deliver the four UX baseline milestone PRs into `phase/ux-baseline` (foundation → POS → catalog/inventory → admin).
2. Satisfy the UX Baseline Gate (system tests + manual walkthrough) before merging to `main`.
3. After the gate: begin Phase 5 foundational purchasing / receiving / requests. See [roadmap.md](roadmap.md) and [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md).
4. Keep [OD-014](open-decisions.md) full settlement/variance representation open for Phase 5; the Phase 4c interim remains accepted.
5. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

## Completed recently

- Phase 4a–4e (Point of Sale) merged to `main` ([phases/phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md)).
- Pre–Phase 4 lightweight UX readiness gate (design docs, tokens, light header) — superseded by this full Baseline Gate for Phase 5 unlock.

## Do not start yet

- Phase 5 screens before the UX Baseline Gate merges to `main`.
- Inventing Phase 5 deficit settlement tables beyond the accepted OD-014 interim.
- Closing [OD-013](open-decisions.md) role/store authority defaults without an accepted decision.
- Deferred capabilities in [deferred-capabilities.md](deferred-capabilities.md).
- PWA / offline POS as adopted architecture.
- External Inter font dependency (see deferred UX in the phase plan).

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Testing: [testing.md](testing.md)
- Services: [service-catalog.md](service-catalog.md)
