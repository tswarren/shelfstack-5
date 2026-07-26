# POS visual contract

**Status:** Draft for Phase 11 layout completion  
**Parent:** [README.md](README.md)  
**Governing UI contract:** [../pos-register-ui.md](../pos-register-ui.md)

## Goal

The ShelfStack POS must behave visually as one dedicated cashier workspace rather than a sequence of ordinary application pages.

Ready, Transaction, Tender, and Recovery must retain recognizable shared geometry. Receipt may use a more focused completion composition, but it must still feel like the conclusion of the same register workflow.

The server remains authoritative. This contract governs presentation, hierarchy, scrolling, focus visibility, and placement of actions; it does not move business rules into views or JavaScript.

## Supported viewports

| Viewport | Contract |
| --- | --- |
| 1366 × 768 | Primary review and acceptance target |
| 1024 × 768 | Minimum supported register viewport |
| Below 1024px wide | Unsupported for register operation in this phase |

At 1366 × 768:

- the register header remains visible;
- the dominant entry or tender control remains visible;
- totals and the primary action remain visible;
- an ordinary eight-line transaction does not require page-level vertical scrolling;
- longer line collections scroll inside the line region;
- the cashier does not scroll the document to reach Tender, Complete Transaction, Recovery resolution, or Next Transaction.

At 1024 × 768:

- the workspace may reduce secondary metadata and horizontal spacing;
- the summary remains usable and visible;
- primary actions do not move below an unbounded content region;
- the layout does not collapse into a generic long single-column page.

## Shared shell

Ready, Transaction, Tender, and Recovery use this high-level composition:

```text
┌──────────────────────────────────────────────────────────────┐
│ Compact register header                                      │
├──────────────────────────────────────┬───────────────────────┤
│ Primary operational workspace        │ Stable summary rail   │
│                                      │                       │
│                                      │                       │
├──────────────────────────────────────┴───────────────────────┤
│ Contextual command bar                                       │
└──────────────────────────────────────────────────────────────┘
```

The implementation may vary the column ratio by presentation, but the regions must be deliberate and recognizable.

### Target geometry

These values are initial design targets, not immutable pixel specifications:

| Region | Target |
| --- | --- |
| Register header | Approximately 48–64px high |
| Summary rail | Approximately 320–380px, or 28–32% of usable width |
| Command bar | Approximately 52–72px high |
| Primary workspace | Consumes remaining width and height |
| Line/results region | `min-height: 0`; internal overflow when needed |

Changes outside these ranges require visual review at both supported viewports.

## Register header

The header is compact and operational. It may show:

- ShelfStack POS identity;
- store;
- register or POS device;
- drawer, where applicable;
- cashier;
- session status;
- current presentation;
- restricted access to Store Operations or the main workspace.

The header must not:

- be followed by a second full-sized page header;
- repeat store and user context in a large subtitle;
- display expected cash, reconciliation variance, or other sensitive financial totals;
- consume enough vertical space to reduce ordinary transaction visibility.

## Primary workspace

The primary workspace contains the cashier’s immediate task.

| Presentation | Primary workspace |
| --- | --- |
| Ready | Scan-to-start and visible work intents |
| Transaction | Entry bar, transaction lines, selected-line context |
| Tender | Tender method, amount entry, recorded tenders |
| Recovery | Incident explanation, verification steps, allowed resolution |
| Receipt | Completion identity, change, print and next-transaction workflow |

The primary workspace must not become a collection of unrelated bordered cards. Components may have visual separation, but partial boundaries do not automatically justify panels or borders.

## Summary rail

The summary rail provides persistent context and the next authoritative progression action.

Typical contents:

- Customer summary;
- transaction totals;
- amount due or refundable;
- readiness or settlement state;
- dynamic primary action;
- compact presentation-specific context.

The rail must remain visible while transaction lines or lookup results scroll.

Tender and Recovery must have intentionally composed primary regions. They must not be produced solely by hiding the Transaction primary column and allowing the former summary rail to become the whole screen.

## Command bar

The command bar contains contextual actions that should remain predictably located.

Examples:

- selected-line commands;
- Suspend;
- Cancel transaction;
- Return to Transaction when safe;
- Complete Transaction;
- Recovery resolution controls;
- Next Transaction and Print Receipt.

The command bar must distinguish:

- dominant progression action;
- ordinary contextual actions;
- destructive or exceptional actions.

Destructive and infrequent actions must not visually compete with the normal next step.

## Scrolling contract

The POS uses the viewport as a bounded workspace.

Required behavior:

- no ordinary document scrolling for an eight-line transaction at 1366 × 768;
- transaction lines scroll internally when necessary;
- lookup results scroll inside their bounded overlay or workspace region;
- the summary rail and primary action remain visible during line scrolling;
- opening an overlay does not make the background independently scrollable;
- focus changes do not unexpectedly scroll the primary action off-screen.

Recommended structural direction:

```css
.layout-pos {
  min-height: 100vh;
  min-height: 100dvh;
}

.pos-shell {
  min-height: 100dvh;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr) auto;
}

.pos-shell__workspace {
  min-height: 0;
  display: grid;
}

.pos-lines,
.pos-results {
  min-height: 0;
  overflow: auto;
}
```

Selectors may differ. The bounded-scrolling behavior is the contract.

## Density and hierarchy

POS-specific density should be tighter than back-office CRUD pages.

Use:

- compact vertical spacing;
- tabular numerals for quantities and money;
- aligned numeric columns;
- a clear dominant amount due, refund due, change due, or remaining balance;
- restrained warning presentation;
- compact labels and secondary metadata;
- limited card nesting;
- stable action placement.

Avoid:

- large page titles inside the workspace;
- full-sized buttons for every possible line action;
- one bordered card per partial;
- repeated explanatory prose during ordinary operation;
- hiding frequent actions in `<details>`;
- displaying low-frequency operational tables in the normal cashier path.

## Entry hierarchy

In Ready and Transaction, scan or exact identifier entry is the dominant control and default focus target.

Visible work intents:

```text
Sale | Return | Stored value | Open ring
```

Receipt lookup is a Ready utility, not a transaction entry intent.

Product lookup, Customer lookup, Receipt lookup, linked-return selection, Stored Value lookup, and compact editors should open as bounded POS-native overlays or workspace panels.

## Lines

The transaction-line collection is the visual center of Transaction.

Each line should make these facts easy to scan:

- description;
- quantity;
- unit price;
- discount;
- tax where useful;
- line total;
- return or Stored Value status;
- important warning or unit-tracking context.

The row itself or an embedded control must be keyboard selectable. Mouse-only row selection is not acceptable.

Uncommon metadata and advanced actions should not permanently expand every row.

## Warnings, blockers, and approvals

| Kind | Visual treatment |
| --- | --- |
| Information | Quiet; no required action |
| Warning | Persistent but does not obscure ordinary work |
| Approval | Interrupts the affected action and returns to the same context |
| Blocker | Clearly associated with the affected line or field; progression disabled |
| Recovery | Occupies the primary workspace and removes unsafe normal controls |

Severity must not be conveyed by color alone.

## Overlays

POS-native overlays are appropriate for bounded supporting work:

- Product lookup;
- Customer lookup and compact creation;
- Receipt lookup;
- linked-return selection;
- Stored Value lookup;
- Open Ring entry;
- discount, price, and tax overrides;
- cash movement entry.

An overlay must:

- have an accessible title;
- trap focus where required;
- close safely with Escape when permitted;
- restore focus to the invoking control;
- preserve the authoritative workspace beneath it;
- avoid creating an empty transaction;
- clear stale content after successful completion.

## Focus and keyboard visibility

Visual order and DOM order must support the same cashier workflow.

Required:

- visible focus indicator;
- Ready and Transaction initially focus scan entry;
- selected-line actions receive focus when explicitly opened;
- validation failure focuses the first resolvable blocker;
- Recovery focuses its primary resolution control;
- Receipt focuses Next Transaction after announcing completion;
- closing an overlay restores meaningful focus;
- all shortcut actions remain available through visible controls.

## Presentation invariants

### Ready

- Scan-to-start is dominant.
- Entry intents are visible.
- Staged Customer and suspended work are discoverable without dominating the screen.
- Session operations are secondary.
- Detailed day/session tables do not appear in the ordinary Ready flow.

### Transaction

- Lines dominate the primary region.
- Totals and progression remain visible.
- Selected-line actions have a stable location.
- Tender-entry forms are not expanded in Transaction.

### Tender

- Tender controls occupy the primary region.
- Recorded tenders and remaining balance are easy to compare.
- Commercial lines are read-only and subordinate.
- Complete Transaction remains visible when settled.

### Recovery

- The blocker occupies the primary region.
- Allowed actions are explicit.
- Unsafe actions are absent, not merely visually muted.
- Normal tender-entry controls do not appear.

### Receipt

- Completion, receipt number, change, Print, and Next Transaction dominate.
- Returns, post-void, and detailed history remain secondary.
- The browser-print receipt uses its separate print layout.

## Visual acceptance checklist

A presentation passes only when all applicable items are true:

- [ ] The next cashier action is immediately apparent.
- [ ] The most important amount or status is visually dominant.
- [ ] Shared regions remain in predictable positions.
- [ ] Ordinary work does not require document scrolling.
- [ ] Only the intended content region scrolls.
- [ ] Totals and the primary action remain visible.
- [ ] Frequent actions are visible or one direct action away.
- [ ] Infrequent actions do not compete with the primary task.
- [ ] Keyboard order matches visual order.
- [ ] Warnings and blockers are associated with their source.
- [ ] Supporting workflows return the cashier to the same context.
- [ ] The result passes at 1366 × 768 and 1024 × 768.
