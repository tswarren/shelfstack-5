# POS layout acceptance status

**Status:** Needs refinement — shell kept; compact presentation + Turbo contract in revision on [#150](https://github.com/tswarren/shelfstack-5/pull/150)  
**Parent:** [README.md](README.md)  
**Checklist:** [layout-completion-checklist.md](layout-completion-checklist.md)  
**Decisions:** [decisions.md](decisions.md)

## Delivery PRs

| Gate | PR | Implementation |
| --- | --- | --- |
| L0–L7 layout revision | [#150](https://github.com/tswarren/shelfstack-5/pull/150) (`feat/phase-11-layout`) | Shell foundation + density/Turbo rework in progress |
| L7 acceptance tracking | this document | Review evidence checklist; Proposed → Accepted promotion rules |

Closed stack (superseded by #150): [#147](https://github.com/tswarren/shelfstack-5/pull/147), [#148](https://github.com/tswarren/shelfstack-5/pull/148), [#149](https://github.com/tswarren/shelfstack-5/pull/149).

Server mechanics baseline: [#146](https://github.com/tswarren/shelfstack-5/pull/146).

## Manual review disposition (2026-07-26)

**Verdict: Needs refinement — block merge** until both issues clear:

1. **Compact presentation** — flat primary/summary composition, single line scroller, pinned progression CTA, non-wrapping command bar + More, selected-line overrides in overlays.
2. **Turbo contract** — `pos_workspace` defaults to `_top`; explicit `pos_workspace` for in-shell mutations; frame-loaded `pos_overlay`; leave-POS uses `_top`.

Do not mark POS-UI-020–037 **Accepted** until screenshots and [review-scenarios.md](review-scenarios.md) walks pass at **1366×768** and **1024×768**.

Score each gate: **Accepted** / **Needs refinement** / **Fail**. Record scores on [#150](https://github.com/tswarren/shelfstack-5/pull/150).

### Capture set (minimum)

See [screenshots/README.md](screenshots/README.md). At minimum capture:

- Ready normal + staged Customer + suspended preview
- Transaction one-line, eight-line, twenty-line (internal scroll)
- Tender positive partial + settled
- Recovery `void_required`
- Receipt with change + Next transaction focus
- Product lookup overlay open (frame-loaded)

### Decision promotion rule

When a Proposed decision is confirmed by review evidence:

1. Change its status to **Accepted** in [decisions.md](decisions.md).
2. Link the PR comment or screenshot evidence.
3. Note residual Needs refinement items explicitly.
