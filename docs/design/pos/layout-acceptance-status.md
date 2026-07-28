# POS layout acceptance status

**Status:** Reduced MVP L7 **Accepted** (human confirmed 2026-07-27); [#150](https://github.com/tswarren/shelfstack-5/pull/150) merged to `main` (`ddb85cb`); exhaustive matrix deferred  
**Parent:** [README.md](README.md)  
**Checklist:** [layout-completion-checklist.md](layout-completion-checklist.md)  
**Decisions:** [decisions.md](decisions.md)
**Latest capture note:** [screenshots/l7-capture-batch-2026-07-27.md](screenshots/l7-capture-batch-2026-07-27.md)

## Delivery PRs

| Gate | PR | Implementation |
| --- | --- | --- |
| L0–L7 layout revision | [#150](https://github.com/tswarren/shelfstack-5/pull/150) (merged) | Shell + density/Turbo; reduced L7 Accepted; P1 overlay error visibility fixed |
| L7 acceptance tracking | this document | Reduced critical set Accepted; residual scenarios deferred |

Closed stack (superseded by #150): [#147](https://github.com/tswarren/shelfstack-5/pull/147), [#148](https://github.com/tswarren/shelfstack-5/pull/148), [#149](https://github.com/tswarren/shelfstack-5/pull/149).

Server mechanics baseline: [#146](https://github.com/tswarren/shelfstack-5/pull/146).

## Reduced MVP merge gate (2026-07-27)

**Verdict: Reduced critical L7 Accepted** (human review). Code remediations and P1 overlay first-step error path shipped on `main` via [#150](https://github.com/tswarren/shelfstack-5/pull/150):

1. Captured at **both** 1366×768 and 1024×768: Ready normal, Transaction 1/8, selected-line commands, Tender unpaid/settled, Recovery `void_required`, Receipt cash/change, Product lookup.
2. **L2 Must criteria** Accepted from those captures (see capture note).
3. Financial / overlay remediations: cost-review stays in frame; PIN not replayed/logged; reviewed cost fields required; cumulative no-receipt authority; Recovery system CI green; **first-step cost-basis failures re-render inside `pos_overlay`** (P1).

Do not mark the full POS-UI-020–037 matrix **Accepted** until residual scenarios in [screenshots/README.md](screenshots/README.md) are captured. Reduced MVP merge may proceed after the P1 overlay error-path correction.

### Capture set (reduced MVP vs full)

**Reduced MVP (Accepted):** Ready normal; Transaction one/eight + selected-line; Tender unpaid/settled; Recovery `void_required`; Receipt change; Product lookup (both viewports).

**Deferred vs full [screenshots/README.md](screenshots/README.md):** staged Customer, suspended, twenty-line, warning/blocker, mixed return, individual unit, partial/split/net-refund tender variants, remaining overlays.

### Decision promotion rule

When a Proposed decision is confirmed by review evidence:

1. Change its status to **Accepted** in [decisions.md](decisions.md).
2. Link the PR comment or screenshot evidence.
3. Note residual Needs refinement items explicitly.
