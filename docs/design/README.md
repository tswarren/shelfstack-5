# ShelfStack Design Documentation

**Status:** Governing for UI direction (below ADRs and Domain Specifications)  
**Prototypes:** [prototypes/ui_mockup/](prototypes/ui_mockup/)  
**Historical drafts:** [../archive/ux-drafts-2026-07/](../archive/ux-drafts-2026-07/)

## Authority

When documents conflict:

1. accepted ADR;
2. Domain Specification;
3. schema documentation;
4. workflow documentation;
5. **these design documents** (visual language, interaction, accessibility);
6. implementation plans;
7. archived or prototype material.

Prototypes illustrate layout, density, and tokens. They do **not** define pricing, tax, inventory, tender, completion, or API contracts. Demo JavaScript is non-authoritative.

Money in ShelfStack is integer cents. The UI may display formatted currency; storage, transmission, and server calculation use cents.

## Documents

| Document | Owns |
| --- | --- |
| [visual-style-guide.md](visual-style-guide.md) | Tokens, typography, buttons, alerts, density |
| [application-shell.md](application-shell.md) | Nav, store/user context, admin vs operational modes |
| [pos-register-ui.md](pos-register-ui.md) | POS layout, session context, state model, warnings/blockers |
| [scanner-and-hotkeys.md](scanner-and-hotkeys.md) | Scan field, focus, progressive hotkeys |
| [accessibility.md](accessibility.md) | Keyboard, focus, contrast, status beyond color |

## Future design docs (not required for Phase 4a gate)

- `interaction-patterns.md` — forms, drawers, shared validation display
- `performance-and-recovery.md` — latency targets, completion failure/retry UI (needed by Phase 4c)

## Roadmap position

UI/UX is a cross-cutting responsibility. A short readiness gate precedes Phase 4a; POS UI and transaction semantics develop together through 4a–4c; broader app-wide consolidation is planned for Phase 5. Timing is tracked in [../implementation/roadmap.md](../implementation/roadmap.md) and [../implementation/current-phase.md](../implementation/current-phase.md).
