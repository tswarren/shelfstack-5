# POS visual decisions

**Status:** Living decision log  
**Parent:** [README.md](README.md)

## Purpose

Record visual and interaction decisions that are more specific than the governing POS domain contract but important enough to preserve across implementation changes.

This is not an ADR replacement. Move a decision to an ADR when it changes system architecture, domain behavior, persistence, posting, or server authority.

## Status values

- **Accepted** — governing unless explicitly revised;
- **Proposed** — initial direction requiring prototype or implementation review;
- **Open** — decision still needed;
- **Superseded** — retained for history with replacement reference.

## Accepted decisions

### POS-UI-001 — Workflow review precedes component review

**Status:** Accepted  
**Decision:** Review cashier workflow and visual composition before reviewing partial structure, Turbo boundaries, or CSS organization.  
**Reason:** Technically reasonable components can still assemble into an unsuitable cashier experience.

### POS-UI-002 — Five cashier-facing presentations

**Status:** Accepted  
**Decision:** The cashier-facing presentation states are Ready, Transaction, Tender, Recovery, and Receipt. They are derived server-side and do not require matching persisted transaction statuses.  
**Related:** [../pos-register-ui.md](../pos-register-ui.md)

### POS-UI-003 — Dedicated register shell

**Status:** Accepted  
**Decision:** The interactive POS uses a dedicated register shell rather than the normal back-office page composition. Ready, Transaction, Tender, and Recovery share recognizable header, primary workspace, summary rail, and command-bar regions.

### POS-UI-004 — Scan entry is dominant

**Status:** Accepted  
**Decision:** Ready and Transaction make scan or exact identifier entry the dominant control and default focus target except while a required bounded task owns input.

### POS-UI-005 — Tender is a distinct composition

**Status:** Accepted  
**Decision:** Tender is not rendered by merely hiding the Transaction primary panel and leaving the former summary panel as the complete workspace. Tender controls occupy an intentional primary region.

### POS-UI-006 — Recovery is a blocking composition

**Status:** Accepted  
**Decision:** Recovery occupies the primary workspace, presents a closed-list structured incident, and omits unsafe normal controls. It is not a banner above ordinary Tender controls.

### POS-UI-007 — Whole-workspace authoritative replacement

**Status:** Accepted  
**Decision:** `pos_workspace` is the normal Turbo consistency boundary for state-changing POS operations. Lines, totals, readiness, Customer, tenders, and primary action are rendered as one coherent server snapshot.

### POS-UI-008 — One transient overlay boundary

**Status:** Accepted  
**Decision:** `pos_overlay` hosts bounded supporting workflows such as lookup, compact creation, overrides, approvals, and cash movement. Successful state-changing actions replace the workspace and close/clear the overlay.

### POS-UI-009 — Internal line scrolling

**Status:** Accepted  
**Decision:** Longer transaction-line collections scroll internally while totals and the primary action remain visible. Ordinary eight-line operation at 1366 × 768 does not require document-level scrolling.

### POS-UI-010 — Frequent actions are not hidden in `<details>`

**Status:** Accepted  
**Decision:** Product lookup, Customer lookup, Receipt lookup, ordinary tender entry, selected-line commands, and common session actions are not primarily exposed through stacked `<details>` sections.

### POS-UI-011 — POS-native supporting workflows

**Status:** Accepted  
**Decision:** Ordinary Product, Customer, Receipt, return, Stored Value, Open Ring, and Cash Movement workflows remain within the POS shell through overlays or bounded workspace panels. Full back-office pages may remain secondary authorized destinations.

### POS-UI-012 — Primary actions are sign- and state-aware

**Status:** Accepted  
**Decision:** Dominant actions use explicit labels such as `Tender $X`, `Issue refund $X`, `Resolve N blockers`, `Add payment $X`, `Add refund $X`, `Complete transaction`, and `Next transaction`. Avoid generic Continue, Submit, or Save as the dominant control.

### POS-UI-013 — Correction actions are subordinate on Receipt

**Status:** Accepted  
**Decision:** Next Transaction, change, and receipt printing dominate Receipt. Linked return, post-void, and detailed history remain available but visually secondary.

### POS-UI-014 — Visual order follows keyboard order

**Status:** Accepted  
**Decision:** DOM order and focus behavior follow the expected cashier workflow even when CSS grid changes visual placement. Shortcuts supplement visible controls and never replace them.

## Proposed decisions requiring visual confirmation

These decisions establish the default design direction. They become Accepted after the identified wireframe, screenshot, and workflow evidence is reviewed.

### POS-UI-020 — Supported register viewports

**Status:** Proposed  
**Decision:** Design and review the register primarily at 1366 × 768 and require full operational usability at 1024 × 768. Widths below 1024px are unsupported for register operation in this phase.

At 1366 × 768:

- an ordinary eight-line transaction does not require document-level scrolling;
- the register header, entry bar, totals, and primary action remain visible;
- longer line collections scroll only inside the line region.

At 1024 × 768:

- the cashier can complete all ordinary workflows;
- the interface remains a two-region register workspace rather than becoming a generic vertically stacked page;
- secondary metadata and actions may be condensed according to the decisions below.

**Reason:** These dimensions represent realistic desktop-register and laptop-register environments and provide measurable review targets.  
**Confirmation:** Approve after Ready, Transaction, Tender, Recovery, and Receipt screenshots and workflow review at both dimensions.

### POS-UI-021 — Compact register header

**Status:** Proposed  
**Decision:** Use one compact register-specific header.

Target dimensions:

- approximately 48–56px at the primary viewport;
- no more than 64px at the minimum supported viewport.

The header displays only operational identity and navigation context:

- store;
- register or POS device;
- drawer where relevant;
- cashier;
- session;
- current presentation;
- restricted exit or Store Operations access.

Do not render a second general page title below the register header.

**Reason:** Operational identity must remain visible without materially reducing transaction-line capacity.  
**Confirmation:** Verify readability and line capacity at both supported viewports.

### POS-UI-022 — Stable summary rail

**Status:** Proposed  
**Decision:** Ready, Transaction, Tender, and Recovery use the same stable summary-rail **location**. Width may grow modestly with the viewport but must not starve the primary workspace.

Target width:

- **1024 × 768:** approximately 320px;
- **1366 × 768:** approximately 340–360px;
- **368px:** hard upper bound, not a target.

The primary workspace receives all remaining usable width. Conceptual direction (exact CSS remains implementation-level):

```css
grid-template-columns: minmax(0, 1fr) clamp(20rem, 26vw, 22.5rem);
```

The rail’s contents change by presentation; its position and approximate width band do not. Tender and Recovery receive dedicated primary-region compositions rather than changing the shell ratio.

Receipt remains excluded: it may use a focused completion composition rather than the ordinary operational rail.

**Reason:** A stable rail preserves spatial memory and prevents each presentation from feeling like a different application page, while the minimum viewport remains the controlling test.  
**Confirmation:** Compare Ready, Transaction, Tender, and Recovery at 1366 × 768 and 1024 × 768.

### POS-UI-023 — Bounded command bar and progression CTA placement

**Status:** Proposed  
**Decision:** Use a persistent command bar approximately 56–72px high for contextual and secondary actions. The state-aware progression CTA is rendered in the summary rail when that rail is present and is never duplicated in the command bar.

Governing rule:

> When a presentation has a summary rail, the state-aware progression action belongs at the bottom of that rail, adjacent to totals, readiness, or settlement status.

The command bar owns:

- selected-line actions;
- secondary transaction actions;
- navigation back to an earlier safe state;
- overflow actions.

It must not duplicate the progression CTA.

| Presentation | Dominant control |
| --- | --- |
| Ready | Scan field and scan-to-start action in the primary workspace |
| Transaction | `Tender $X`, `Issue refund $X`, or `Resolve N blockers` in the summary rail |
| Tender | `Add payment $X`, `Add refund $X`, or `Complete transaction` in the summary rail |
| Recovery | Required recovery action in the primary Recovery workspace |
| Receipt | `Next transaction` in the Receipt completion action area |

Command bar examples:

**Transaction**

```text
[ Qty ] [ Remove ] [ Discount ] [ Price override ]   [ More ]
                                     [ Suspend ] [ Cancel ]
```

**Tender**

```text
[ Return to Transaction ] [ Remove selected tender ] [ More ]
```

**Recovery**

The command bar should normally be absent or extremely limited. Recovery’s permitted resolution belongs alongside its instructions.

**Receipt**

Secondary actions only:

```text
[ Print ] [ Reprint ] [ View detail ] [ More ]
```

`Next transaction` must not appear again in the command bar.

At 1366 × 768, ordinary commands must not wrap. At 1024 × 768, lower-priority actions may move into a clearly labeled overflow menu; the most common contextual actions remain visible.

**Reason:** One dominant action per presentation; the command bar must provide predictable placement without consuming unbounded space or competing with progression.  
**Confirmation:** Review Transaction selected-line actions, Tender completion, Recovery resolution, and Receipt handoff at both viewports.  
**Related:** POS-UI-012, POS-UI-013

### POS-UI-024 — Semantic transaction table

**Status:** Proposed  
**Decision:** Continue using semantic table markup for transaction lines.

The table must support:

- keyboard-accessible selection;
- compact numeric alignment;
- a persistent header;
- return and warning indicators;
- individually tracked unit information;
- internal vertical scrolling;
- sensible handling of long descriptions.

A different grid or list structure requires evidence that it is more accessible and operationally clearer.

**Reason:** Transaction lines are fundamentally tabular and benefit from aligned quantity, price, discount, tax, and net columns.  
**Confirmation:** Review keyboard operation, screen-reader semantics, narrow-width behavior, warning metadata, and row density.

### POS-UI-025 — Contextual selected-line commands

**Status:** Proposed  
**Decision:** Place common selected-line actions in the stable command bar.

The four ordinary visible selected-line actions are:

1. Quantity  
2. Remove  
3. Discount  
4. Price override  

Use the label **Price override**, not a generic Override.

Complex, uncommon, or authorization-sensitive actions open from a clearly labeled additional-actions control (or overlay), including:

- Tax Category Override;
- return disposition;
- exact Inventory Unit selection;
- required approval details;
- extended line information;
- other uncommon or policy-dependent actions.

Do not expand full action sets inside every line row.

**Reason:** Routine changes should not require expanding controls inside the line row, while uncommon forms should not overload the command bar.  
**Confirmation:** Review ordinary sale, discounted line, return, and individually tracked line scenarios.

### POS-UI-026 — Overlay implementation belongs in the component map

**Status:** Superseded  
**Decision:** The requirement for one bounded, focus-contained transient overlay is governed by POS-UI-008.

The choice to implement that overlay with native `<dialog>`, a particular Stimulus controller, or another accessible mechanism belongs in [component-map.md](component-map.md) and implementation review.

**Reason:** The decision log should preserve the interaction contract rather than prematurely lock a specific HTML element or controller name.  
**Replaces:** The former proposal requiring native `<dialog>` and `pos-dialog`.

### POS-UI-027 — Operational Product lookup

**Status:** Proposed  
**Decision:** Product lookup must provide enough operational context for a cashier to choose deliberately among ambiguous or multi-variant results.

Each result should show, where applicable:

- Product title;
- Product Variant;
- format or condition;
- primary identifier;
- selling price;
- available quantity;
- quantity-tracked or individually tracked status.

The shared generic record picker may be reused only when it can present this information clearly. Otherwise, use a POS-specific result component.

**Reason:** A title and internal record ID are insufficient when several variants, formats, conditions, or tracked units may match.  
**Confirmation:** Review ambiguous title, multi-variant, used/new, and individually tracked scenarios.

### POS-UI-030 — Presentation-specific shell ratios

**Status:** Superseded  
**Decision:** Superseded by POS-UI-022.

Ready, Transaction, Tender, and Recovery use a stable summary-rail location and viewport-scaled width band. Presentation differences are expressed through their primary-region composition, not different shell ratios.

**Replaces:** The former open question about fixed versus presentation-specific ratios.

### POS-UI-031 — Minimum transaction-line density

**Status:** Proposed  
**Decision:** The transaction line region must fully display:

- at least eight ordinary lines at 1366 × 768;
- at least six ordinary lines at 1024 × 768.

These are acceptance constraints, not approximate aspirations. An ordinary line uses one principal description row. A title may wrap to a second line when necessary, but uncommon metadata must not permanently expand every row.

At 1024 × 768:

- secondary identifiers may be condensed;
- uncommon metadata may move to the selected-line context or overlay;
- quantity, price, discount, tax, and net remain understandable;
- return and warning status remain visible.

Longer transactions scroll internally.

If a composition fails the line-capacity target, reduce surrounding chrome first—do not silently relax the target. Review order:

1. remove redundant headings and labels;
2. reduce register-header height;
3. reduce entry-bar padding;
4. reduce command-bar padding;
5. reduce nested borders and card spacing;
6. refine row padding and metadata placement;
7. only then reconsider the line target through an explicit decision revision.

**Reason:** A measurable line-capacity target is necessary to assess whether the register is genuinely compact.  
**Confirmation:** Review one-, six-, eight-, and twenty-line transactions using realistic titles and metadata.

### POS-UI-032 — Hybrid line selection

**Status:** Proposed  
**Decision:** Use a hybrid line-selection model:

- provide a compact explicit keyboard-focusable selection control;
- allow pointer activation on the row to invoke the same selection behavior;
- visually distinguish the selected row;
- support deterministic keyboard movement between rows.

Do not use a large Select button in every row. Do not rely on mouse-only row clicking.

**Reason:** An explicit control provides accessible semantics, while row activation supports rapid cashier operation.  
**Confirmation:** Review keyboard-only, pointer, and screen-reader interaction.

### POS-UI-033 — Ready action tiers

**Status:** Proposed  
**Decision:** Ready uses two visible tiers of customer-work actions. Ready launchers are not the same component or hierarchy as Transaction entry intents.

**Primary work area:**

```text
Scan / exact identifier                         [ Scan to start ]
[ Product lookup ] [ Start return ]
```

**Visible supporting customer-work actions:**

```text
[ Customer ] [ Receipt lookup ] [ Open Ring ]
[ Stored Value ] [ Pickup / Product Request ]
```

A Ready-level Sale intent is not shown: scanning already starts a sale by default; a Sale control without work is useless and may imply empty-transaction creation.

**Transaction remains different.** Once a transaction exists, the four-intent Entry Bar remains appropriate:

```text
Sale | Return | Stored Value | Open Ring
```

At that point the intent changes how the next line-entry operation is interpreted and is therefore meaningful and reload-safe.

Administrative and session-management functions may use a separate utility area or Store Operations surface (see POS-UI-037).

**Reason:** Scan remains dominant, but ordinary non-scan workflows must remain discoverable without stacked disclosures or equal visual weight for unequal frequencies.  
**Confirmation:** Review Ready at both viewports with and without a staged Customer.  
**Related:** Updates Ready composition in [wireframes.md](wireframes.md), [visual-contract.md](visual-contract.md), [presentation-matrix.md](presentation-matrix.md), and [component-map.md](component-map.md).

### POS-UI-034 — Suspended transaction preview

**Status:** Proposed  
**Decision:** Show a compact suspended-transaction preview in the Ready summary rail.

The preview may show up to three relevant suspended transactions, including:

- transaction reference;
- Customer where permitted;
- line count or amount;
- suspended time;
- recall action.

When additional suspended transactions exist, show a `View all (N)` launcher that opens a bounded overlay.

**Reason:** Suspended work must remain discoverable without allowing a long recall list to dominate Ready.  
**Confirmation:** Review Ready with zero, one, three, and more than three suspended transactions.

### POS-UI-035 — Reload-safe Tender method selection

**Status:** Proposed  
**Decision:** Tender-method selection uses reload-safe GET or query navigation, such as `tender_method=cash|card|stored_value`.

Selecting a method:

- does not create or modify tender activity;
- renders the appropriate form server-side;
- remains understandable after refresh;
- does not depend on client-only transaction state.

The normal implementation should replace the complete `pos_workspace`. A smaller nonauthoritative frame may be adopted later only when it provides a demonstrated benefit without creating inconsistent transaction information.

**Reason:** The selected input method is presentational, but reload and error behavior should remain predictable.  
**Confirmation:** Review Cash, Card, Stored Value, validation-error, refresh, and Back behavior.

### POS-UI-036 — Receipt detail in a read-only overlay

**Status:** Proposed  
**Decision:** Receipt shows only the completion information needed for the immediate cashier handoff.

A `View transaction detail` action opens a read-only bounded overlay containing full line and tender detail.

The interactive Receipt presentation should not permanently display a large completed line table below the primary completion actions.

The printable customer receipt remains a separate print layout.

**Reason:** Change due, receipt identity, printing, and Next Transaction should dominate the completed state.  
**Confirmation:** Review cash, split-tender, return, and long-transaction receipts.

### POS-UI-037 — Ready and Store Operations boundary

**Status:** Proposed  
**Decision:** Keep the following directly reachable from Ready:

- Cash Movement;
- No Sale;
- Store Operations.

Ready also displays compact current-session identity and status.

Move the following into the dedicated Store Operations surface:

- Session X detail;
- Close Session;
- Day X and Day Z;
- Session Z history;
- other-session tables;
- business-day close;
- detailed cash-movement history;
- operational diagnostics.

Store Operations is one obvious action from Ready. For an authorized user, Close Session is a prominent first-level action inside Store Operations and does not require navigating through an additional report or administration menu.

Review path:

```text
Ready → Store Operations → Close Session
```

No additional navigation layer should be required.

Permissions may hide or disable actions, but should not change the fundamental boundary.

**Reason:** Routine register actions should remain reachable while reporting, closing, and multi-session administration should not compete with customer work.  
**Confirmation:** Review Cashier, Lead Cashier, Supervisor, and Manager permission sets.

## Open decisions

There are currently no unresolved visual-direction decisions.

The Proposed decisions above still require prototype, screenshot, workflow, accessibility, and implementation confirmation. A failed confirmation returns the affected decision to review rather than allowing the implementation to choose an undocumented alternative.

## Decision record template

```markdown
### POS-UI-NNN — Decision title

**Status:** Proposed | Accepted | Open | Superseded  
**Decision or question:**  
**Reason:**  
**Alternatives considered:**  
**Evidence:** wireframe, screenshot, scenario, test, or PR  
**Replaces:** optional decision ID  
**Accepted date:** YYYY-MM-DD
```

## Revision rules

- Change an Accepted decision only with explicit review and a new or superseding decision entry.
- Link screenshot or scenario evidence where practical.
- Keep implementation-specific naming in [component-map.md](component-map.md), not here, unless the naming itself is part of the accepted interaction contract.
