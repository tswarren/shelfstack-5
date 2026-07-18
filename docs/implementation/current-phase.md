# Current Phase

**Active delivery phase:** Phase 2 — Configuration and catalog  
**Status:** Not started  
**Plan document:** [phases/phase-02-configuration-and-catalog.md](phases/phase-02-configuration-and-catalog.md)

## Immediate next work

1. Implement Phase 2 from [phases/phase-02-configuration-and-catalog.md](phases/phase-02-configuration-and-catalog.md).
2. Resolve or respect [OD-011](https://github.com/tswarren/shelfstack-5/issues/14) (identifier generation) and [OD-012](open-decisions.md) as needed for catalog scaffolding.
3. Keep [architectural-locks.md](architectural-locks.md) binding; track unresolved items in [open-decisions.md](open-decisions.md).

### Pre-migration scrub checklist (completed in Phase 0)

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

- POS, purchasing, or receiving tables before their phase prerequisites.
- Closing [OD-003](open-decisions.md) / [OD-004](open-decisions.md) by inventing ad hoc formulas in code.
- Closing [OD-013](open-decisions.md) role/store authority defaults before Phase 4b needs them.
- Deferred capabilities listed in [deferred-capabilities.md](deferred-capabilities.md).

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Identifiers: [../reference/identifiers.md](../reference/identifiers.md)
- Testing mechanics: [testing.md](testing.md)
- Services: [service-catalog.md](service-catalog.md)
