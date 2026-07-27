# POS layout acceptance status

**Status:** Reduced MVP merge-gate evidence ready on [#150](https://github.com/tswarren/shelfstack-5/pull/150) — critical L7 viewports + L2 Must scores captured; exhaustive matrix deferred  
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

## Reduced MVP merge gate (2026-07-27)

**Verdict: Ready for human L7/L2 score on the reduced critical set** (exhaustive matrix deferred):

1. Captured at **both** 1366×768 and 1024×768: Ready normal, Transaction 1/8, selected-line commands, Tender unpaid/settled, Recovery `void_required`, Receipt cash/change, Product lookup.
2. **L2 Must criteria** scored Accepted from those captures (see capture note): single ordinary line scroller, selected-line commands, pinned totals/primary CTA, line selection, no clipped primary controls, overlay bounded/closable.
3. Financial Gates F1/F2 remediations: cost-review overlay frame fix, PIN not replayed/logged, reviewed cost fields required, cumulative no-receipt authority, Recovery system CI green.

Do not mark the full POS-UI-020–037 matrix **Accepted** until residual scenarios in [screenshots/README.md](screenshots/README.md) are captured. Reduced MVP merge may proceed once reviewers confirm the critical set.

Score each gate: **Accepted** / **Needs refinement** / **Fail**. Record scores on [#150](https://github.com/tswarren/shelfstack-5/pull/150).

### Capture set (reduced MVP vs full)

**Reduced MVP (present):** Ready normal; Transaction one/eight + selected-line; Tender unpaid/settled; Recovery `void_required`; Receipt change; Product lookup (both viewports).

**Deferred vs full [screenshots/README.md](screenshots/README.md):** staged Customer, suspended, twenty-line, warning/blocker, mixed return, individual unit, partial/split/net-refund tender variants, remaining overlays.

### Decision promotion rule

When a Proposed decision is confirmed by review evidence:

1. Change its status to **Accepted** in [decisions.md](decisions.md).
2. Link the PR comment or screenshot evidence.
3. Note residual Needs refinement items explicitly.
