# POS layout acceptance status

**Status:** Implementation delivered; viewport acceptance pending  
**Parent:** [README.md](README.md)  
**Checklist:** [layout-completion-checklist.md](layout-completion-checklist.md)  
**Decisions:** [decisions.md](decisions.md)

## Delivery PRs

| Gate | PR | Implementation |
| --- | --- | --- |
| L0–L7 layout + Ready action fixes | [#150](https://github.com/tswarren/shelfstack-5/pull/150) (`feat/phase-11-layout`) | Dedicated shell, presentation regions, overlay host, supporting actions, Next-transaction breakout |
| L7 acceptance tracking | this document | Review evidence checklist; Proposed → Accepted promotion rules |

Closed stack (superseded by #150): [#147](https://github.com/tswarren/shelfstack-5/pull/147), [#148](https://github.com/tswarren/shelfstack-5/pull/148), [#149](https://github.com/tswarren/shelfstack-5/pull/149).

Server mechanics baseline: [#146](https://github.com/tswarren/shelfstack-5/pull/146).

## Manual review required

Do not mark POS-UI-020–037 **Accepted** until screenshots and [review-scenarios.md](review-scenarios.md) walks pass at **1366×768** and **1024×768**.

Score each gate: **Accepted** / **Needs refinement** / **Fail**. Record scores on [#150](https://github.com/tswarren/shelfstack-5/pull/150).

### Capture set (minimum)

See [screenshots/README.md](screenshots/README.md). At minimum capture:

- Ready normal + staged Customer + suspended preview
- Transaction one-line, eight-line, twenty-line (internal scroll)
- Tender positive partial + settled
- Recovery `void_required`
- Receipt with change + Next transaction focus
- Product lookup overlay open

### Decision promotion rule

When a Proposed decision is confirmed by review evidence:

1. Change its status to **Accepted** in [decisions.md](decisions.md).
2. Link the PR comment or screenshot evidence.
3. Do not invent undocumented alternatives on Fail — return the decision to review.

## Residuals (known)

| Item | Disposition |
| --- | --- |
| POS-UI-027 rich Product lookup fields | Record picker interim until rich result component lands |
| Store Operations Close Session surface | Link from Ready exists; dedicated Store Operations page layout is follow-on |
| Selected-line command bar density | Still renders fuller action partials; refine to Qty/Remove/Discount/Price override + More |
| Screenshot artifacts in repo | Attach on PR review or under `docs/design/pos/screenshots/` when captured |
