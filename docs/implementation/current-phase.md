# Current Phase

**Active delivery phase:** Phase 0 — Scaffold and architectural locks  
**Status:** Not started  
**Plan document:** [phases/phase-00-scaffold-and-locks.md](phases/phase-00-scaffold-and-locks.md)

## Immediate next work

1. Complete Phase 0 scaffold hygiene (Compose/DB naming, `bin/ci` green, service layout).
2. Treat [architectural-locks.md](architectural-locks.md) as binding; track unresolved items in [open-decisions.md](open-decisions.md).
3. Finish pre-migration classification scrub (checklist below).
4. Begin Phase 1 using [authorization-permissions.md](../domains/authorization-permissions.md) for seeds.

### Pre-migration scrub checklist (Phase 0 / before Phase 2)

- [x] No separate display-category tables or `*_display_category_id` fields
- [x] Merchandise class is hierarchical; department defaults resolve correctly
- [x] Product / variant / unit ownership matches ADR-0001
- [x] Quantity vocabulary uses `reserved`, not `pending`
- [x] Store-level inventory boundary preserved
- [x] One canonical product identifier; `21` / `27` / `28` / `29` prefixes correct
- [x] No obsolete special-order / TBO substitutes on PO lines
- [x] Receipt-to-PO linkage at line level only
- [x] Money fields use integer cents
- [x] No premature customer CRM, transfer, RTV, or buyback structures

Audit completed 2026-07-17. See [phases/phase-00-scaffold-and-locks.md](phases/phase-00-scaffold-and-locks.md) § Audit result.

## Do not start yet

- Catalog migrations before the classification-field audit completes.
- POS, purchasing, or receiving tables before their phase prerequisites.
- Closing [OD-003](open-decisions.md) / [OD-004](open-decisions.md) by inventing ad hoc formulas in code.
- Deferred capabilities listed in [deferred-capabilities.md](deferred-capabilities.md).

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Identifiers: [../reference/identifiers.md](../reference/identifiers.md)
- Testing mechanics: [testing.md](testing.md)
- Services: [service-catalog.md](service-catalog.md)
