# POS screenshot evidence

**Status:** Capture manifest  
**Parent:** [../README.md](../README.md)  
**Scenarios:** [../review-scenarios.md](../review-scenarios.md)

## Purpose

Store or index deterministic screenshot evidence used to review POS hierarchy, density, scrolling, and presentation continuity.

Screenshots are evidence, not the sole specification. Governing rules remain in the surrounding design documents.

## Required viewports

Capture each mandatory scenario at:

- `1366x768` — primary target;
- `1024x768` — minimum supported target.

Use 100% browser zoom unless a screenshot explicitly documents otherwise.

## Required scenario set

### Ready

- normal Ready;
- staged Customer;
- suspended transactions or suspended-work launcher;
- ambiguous scan;
- no business day;
- no session.

### Transaction

- one line;
- eight lines;
- twenty lines with internal scrolling;
- selected line and command bar;
- warning;
- blocker;
- mixed sale and return;
- individually tracked line.

### Tender

- positive balance before tender;
- partial cash;
- partial card;
- split tender with remaining balance;
- settled tender;
- net refund;
- forced Tender with Return to Transaction absent.

### Recovery

- `void_required` with structured instructions and allowed actions.

### Receipt

- cash completion with change;
- card completion;
- split tender;
- refund completion;
- correction actions visible but secondary.

### Overlays

- Product lookup with multiple variants;
- Customer lookup;
- compact Customer creation;
- Receipt lookup;
- linked-return selection;
- one authorization-sensitive line action.

## Naming convention

```text
<presentation>-<scenario>-<viewport>-<state>.<ext>
```

Examples:

```text
ready-normal-1366x768-accepted.png
transaction-eight-lines-1366x768-needs-refinement.png
tender-split-1024x768-accepted.png
recovery-void-required-1366x768-accepted.png
receipt-cash-change-1024x768-accepted.png
```

Use lowercase kebab case. Keep the scenario name stable so before/after images sort together.

## Directory suggestion

```text
screenshots/
  ready/
  transaction/
  tender/
  recovery/
  receipt/
  overlays/
```

Git does not retain empty directories. Create subdirectories as screenshots are added.

## Capture metadata

For each review batch, record in the PR or a nearby Markdown file:

- commit SHA;
- browser and version;
- operating system;
- viewport;
- browser zoom;
- fixture or seed scenario;
- reviewer;
- status: Accepted, Needs refinement, or Fail;
- associated decision IDs;
- known deviations.

## Screenshot review checklist

- [ ] The viewport dimensions are exact.
- [ ] The screenshot shows the complete browser content area used for review.
- [ ] The presentation label and operational context are visible where expected.
- [ ] The primary action is visible.
- [ ] Totals or remaining balance are visible.
- [ ] The intended scrolling region is evident.
- [ ] No accidental document scrollbar is present in ordinary target scenarios.
- [ ] Focus indicator is captured for keyboard-specific reviews where useful.
- [ ] Warnings and blockers use more than color.
- [ ] Sensitive or prohibited data is not exposed.
- [ ] The screenshot uses deterministic, nonproduction data.

## Pull request template fragment

```markdown
## POS visual acceptance

### Build

- Commit:
- Browser/OS:
- Fixture/seed:

### Viewports

- [ ] 1366 × 768
- [ ] 1024 × 768

### Presentations

- [ ] Ready
- [ ] Transaction — 1 line
- [ ] Transaction — 8 lines
- [ ] Transaction — 20 lines
- [ ] Tender — unpaid
- [ ] Tender — split
- [ ] Tender — settled
- [ ] Recovery
- [ ] Receipt
- [ ] Required overlays

### Interaction contract

- [ ] Scan input receives expected focus
- [ ] Primary action remains visible
- [ ] Totals remain visible
- [ ] Long line list scrolls internally
- [ ] No ordinary document scrolling
- [ ] Overlay closes and restores focus
- [ ] Tender and Recovery have dedicated compositions

### Findings

1.
2.

### Decision updates

- POS-UI-
```

## Storage policy

Small, stable, governing screenshots may be committed here. Large iterative screenshot sets may instead be attached to the relevant PR, with links and acceptance conclusions recorded in the design decision log.

Do not commit screenshots containing real Customer, payment, employee, or store-sensitive data.
