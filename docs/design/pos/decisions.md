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

### POS-UI-020 — Primary viewport targets

**Status:** Proposed  
**Decision:** Review primarily at 1366 × 768 and require usability at 1024 × 768. Widths below 1024px are unsupported for register operation in this phase.  
**Confirmation:** Approve after shell screenshots and workflow review at both sizes.

### POS-UI-021 — Register header height

**Status:** Proposed  
**Decision:** Target approximately 48–64px.  
**Confirmation:** Verify operational identity remains readable without materially reducing line capacity.

### POS-UI-022 — Summary rail width

**Status:** Proposed  
**Decision:** Target approximately 320–380px, or 28–32% of usable width. Presentation-specific ratios may vary.  
**Confirmation:** Compare Transaction, Tender, and Recovery at both supported viewports.

### POS-UI-023 — Command-bar height

**Status:** Proposed  
**Decision:** Target approximately 52–72px with one clear primary action and compact secondary actions.  
**Confirmation:** Verify selected-line and tender workflows without wrapping or obscuring content.

### POS-UI-024 — Semantic transaction table

**Status:** Proposed  
**Decision:** Continue using semantic table markup for transaction lines unless testing demonstrates that a grid/list pattern is more accessible and operationally clearer.  
**Confirmation:** Review keyboard selection, narrow-width behavior, long titles, warning metadata, and row density.

### POS-UI-025 — Selected-line commands in command bar

**Status:** Proposed  
**Decision:** Use the command bar as the stable location for common selected-line actions, with complex actions opening overlays.  
**Confirmation:** Review quantity change, remove, discount, price override, return disposition, and unit selection.

### POS-UI-026 — Native `<dialog>` overlay host

**Status:** Proposed  
**Decision:** Use one native `<dialog>` host with Turbo-loaded content and a dedicated `pos-dialog` Stimulus controller.  
**Confirmation:** Verify browser support, focus containment, Escape behavior, screen-reader labeling, and Turbo replacement.

### POS-UI-027 — Rich Product lookup

**Status:** Proposed  
**Decision:** Use a POS-specific Product lookup result list when the generic record picker does not expose enough operational context.  
**Candidate fields:** title, variant, format, identifier, price, available quantity, tracking status.  
**Confirmation:** Review against ambiguous title and multi-variant scenarios.

## Open decisions

### POS-UI-030 — Exact shell ratios by presentation

**Status:** Open  
**Question:** Should Ready, Transaction, Tender, and Recovery use one fixed column ratio, or documented presentation-specific ratios?

### POS-UI-031 — Transaction row density

**Status:** Open  
**Question:** How many ordinary lines should be fully visible at 1024 × 768, and which secondary metadata may be hidden or condensed there?

### POS-UI-032 — Line selection control

**Status:** Open  
**Question:** Should selection use a compact explicit control, a focusable row with keyboard semantics, or a hybrid? Mouse-only row selection is prohibited.

### POS-UI-033 — Ready intent presentation

**Status:** Open  
**Question:** Which work intents remain permanently visible and which utilities move into a secondary menu without reducing discoverability?

### POS-UI-034 — Suspended transaction placement

**Status:** Open  
**Question:** Should a compact suspended-work list remain in the Ready summary rail, or should Ready show only a count/launcher to a bounded overlay?

### POS-UI-035 — Tender method switching

**Status:** Open  
**Question:** Should method switching use URL/query navigation, a small local Turbo Frame, or a Stimulus-only presentational switch?

### POS-UI-036 — Receipt detail placement

**Status:** Open  
**Question:** Should completed line detail appear in a bounded secondary region, a disclosure, or a separate read-only view linked from Receipt?

### POS-UI-037 — Store Operations boundary

**Status:** Open  
**Question:** Which session/day controls remain directly on Ready, and which move to a dedicated Store Operations surface?

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
