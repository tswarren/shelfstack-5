# POS layout acceptance status

**Status:** Needs refinement — MVP remediations landed on [#150](https://github.com/tswarren/shelfstack-5/pull/150); core L7 viewport captures present; residual scenario set + Accepted scoring still required before merge  
**Parent:** [README.md](README.md)  
**Checklist:** [layout-completion-checklist.md](layout-completion-checklist.md)  
**Decisions:** [decisions.md](decisions.md)
**Latest capture note:** [screenshots/l7-capture-batch-2026-07-27.md](screenshots/l7-capture-batch-2026-07-27.md)

## Delivery PRs

| Gate | PR | Implementation |
| --- | --- | --- |
| L0–L7 layout revision | [#150](https://github.com/tswarren/shelfstack-5/pull/150) (`feat/phase-11-layout`) | Shell foundation + density/Turbo rework in progress |
| L7 acceptance tracking | this document | Review evidence checklist; Proposed → Accepted promotion rules |

Closed stack (superseded by #150): [#147](https://github.com/tswarren/shelfstack-5/pull/147), [#148](https://github.com/tswarren/shelfstack-5/pull/148), [#149](https://github.com/tswarren/shelfstack-5/pull/149).

Server mechanics baseline: [#146](https://github.com/tswarren/shelfstack-5/pull/146).

## Manual review disposition (2026-07-26)

**Verdict: Needs refinement — block merge** until L7 viewport evidence Accepted:

1. Capture Ready / Transaction / Tender / Recovery / Receipt at **1366×768** and **1024×768**.
2. **L2 Must criteria are merge blockers** (not optional polish): single ordinary line scroller, stable selected-line commands, pinned totals/progression CTA, keyboard line selection, eight-line 1366×768 composition.
3. Financial Gates F1 (unlinked return tax/cost basis) and F2 (No Sale event) are PR review checkpoints — they do not replace L7.

Do not mark POS-UI-020–037 **Accepted** until screenshots and [review-scenarios.md](review-scenarios.md) walks pass at both viewports.

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
