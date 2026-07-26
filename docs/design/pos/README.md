# POS visual review package

**Status:** Draft governing package for Phase 11 layout completion  
**Parent contract:** [../pos-register-ui.md](../pos-register-ui.md)  
**Related:** [../scanner-and-hotkeys.md](../scanner-and-hotkeys.md); [../accessibility.md](../accessibility.md)  
**Phase plan:** [../../implementation/phases/phase-11-pos-shell-and-workspace-revamp.md](../../implementation/phases/phase-11-pos-shell-and-workspace-revamp.md)

## Purpose

This directory defines how ShelfStack reviews and accepts the cashier-facing POS workspace.

The existing POS domain and Phase 11 server contracts remain authoritative for transaction, reservation, tender, completion, receipt, and Recovery behavior. These documents add the missing measurable visual and workflow contract: what the cashier sees, what remains visible, how the workspace is composed, and how reviewers determine whether the result is acceptable.

The package deliberately separates three review layers:

1. cashier workflow;
2. visual composition;
3. Rails/Hotwire implementation structure.

Review them in that order. A technically clean partial hierarchy does not compensate for an unclear cashier workflow.

## Documents

| Document | Purpose |
| --- | --- |
| [visual-contract.md](visual-contract.md) | Supported viewports, shell geometry, density, scrolling, hierarchy, and visual invariants |
| [presentation-matrix.md](presentation-matrix.md) | Required Ready, Transaction, Tender, Recovery, and Receipt scenarios |
| [wireframes.md](wireframes.md) | Annotated low-fidelity compositions for the shell, presentations, and primary overlays |
| [component-map.md](component-map.md) | Partials, forms, Turbo boundaries, Stimulus responsibilities, and current-to-target mapping |
| [review-scenarios.md](review-scenarios.md) | Scripted cashier walkthroughs and acceptance procedure |
| [decisions.md](decisions.md) | Accepted, proposed, and open visual decisions |
| [screenshots/README.md](screenshots/README.md) | Screenshot naming, capture matrix, and review evidence requirements |

## Required review sequence

```text
Presentation matrix
      ↓
Annotated wireframes or prototype
      ↓
Shell-only implementation
      ↓
Presentation-by-presentation vertical slices
      ↓
Scripted cashier walkthroughs
      ↓
Viewport screenshot review
      ↓
Component and code review
      ↓
Acceptance
```

## Sources of authority

When documents appear to conflict, apply this order:

1. accepted architecture decisions and domain specifications;
2. Phase 11 server-authority and presentation-state contracts;
3. [../pos-register-ui.md](../pos-register-ui.md);
4. this visual review package;
5. prototypes and screenshots;
6. implementation details.

A prototype may demonstrate composition, but it must not redefine pricing, tax, reservation, tender, completion, or correction behavior.

## Maintenance rules

- Update the presentation matrix when a new cashier-visible state or materially different scenario is introduced.
- Update [wireframes.md](wireframes.md) when accepted hierarchy or region placement changes.
- Record accepted layout choices in [decisions.md](decisions.md).
- Update the component map when Turbo boundaries or partial responsibilities change.
- Capture deterministic screenshots for visual changes that alter hierarchy, density, scrolling, or primary actions.
- Do not mark the POS layout complete solely because controller, service, or selector tests pass.
- Do not use screenshots as the only specification; preserve the underlying rules in text.

## Completion standard

The POS visual refactor is complete only when:

- the required presentation scenarios have approved compositions;
- the supported viewports satisfy the visual contract;
- scripted cashier walkthroughs pass;
- screenshot evidence is attached or stored;
- implementation boundaries match the component map or an explicitly recorded replacement;
- all existing domain and server-authority tests continue to pass.
