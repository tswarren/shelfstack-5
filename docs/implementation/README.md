# ShelfStack Implementation Documentation

**Status:** Governing delivery documentation  
**Purpose:** Track how ShelfStack is built in the Rails repository, in what order, and under which architectural locks

## How to use these documents

| Document | Role |
| --- | --- |
| [roadmap.md](roadmap.md) | Master sequence, status, and mapping to system-overview phases |
| [../design/README.md](../design/README.md) | Cross-cutting UI direction, POS interaction, accessibility; prototypes |
| [git-workflow.md](git-workflow.md) | Trunk-based branching, PR, and merge conventions |
| [current-phase.md](current-phase.md) | What is in progress right now |

| [architectural-locks.md](architectural-locks.md) | Settled delivery decisions that must not be re-litigated mid-phase |
| [open-decisions.md](open-decisions.md) | Living queue of unresolved choices (needed-by phase + disposition) |
| [deferred-work-register.md](deferred-work-register.md) | Authoritative Phases 1–7 carry-forward backlog (ODs, interim blocks, delivery debt, catalog candidates, later extensions) |
| [deferred-capabilities.md](deferred-capabilities.md) | Short anti-invention list; later extensions until designed |
| [testing.md](testing.md) | Project test mechanics (fixtures, concurrency, idempotency patterns) |
| [bootstrap-and-seed.md](bootstrap-and-seed.md) | Seed layers, bootstrap env vars, INV-ORG-001, admin permission sync |
| [service-catalog.md](service-catalog.md) | Introduced application services as they land |
| [phases/](phases/) | Per-phase goals, tables, services, exit criteria, and out-of-scope |
| [phase-05-ordering-scope-and-future-lifecycle-boundaries.md](phase-05-ordering-scope-and-future-lifecycle-boundaries.md) | Phase 5 in-scope vs deferred vendor-order lifecycle boundaries |
| [decisions/](decisions/) | Accepted decision write-ups (OD-007, OD-014 Phase 5 settlement, Phase 6 post-void / inventory / stored-value) |
| [phase-03-inventory-cost-schema.md](phase-03-inventory-cost-schema.md) | Authoritative Phase 3 quantity-cost fields and constraints (ADR-0013) |
| [phase-04-tax-schema.md](phase-04-tax-schema.md) | Authoritative Phase 4 tax/POS commercial schema deltas (ADR-0014) |
| [design-notes/inventory-costing/](design-notes/inventory-costing/) | Non-authoritative inventory-costing exploration notes |
| [schema-reconciliation-display-categories-and-demand-allocation.md](schema-reconciliation-display-categories-and-demand-allocation.md) | Pre-scaffolding schema decisions (merchandise classes, requests, allocations) |

## Authority

Implementation plans sit below ADRs and Domain Specifications:

1. accepted ADR;
2. Domain Specification;
3. schema documentation / reconciled proforma;
4. workflow documentation;
5. design documentation ([../design/](../design/README.md));
6. **these implementation documents**;
7. archived material.


When delivery order differs from the conceptual sequence in [system-overview §1.8](../architecture/system-overview.md), this roadmap is authoritative for **build order**. It does not change domain ownership or invariants.

## Cursor rules

Project Cursor rules under [`.cursor/rules/`](../../.cursor/rules/) reinforce this documentation:

- `shelfstack-planning.mdc` — always on; roadmap, ODs, git workflow
- `shelfstack-docker.mdc` — always on; prefer `./dev/rails-docker` / Compose for Rails commands
- `shelfstack-implementation-docs.mdc` — when editing `docs/implementation/**`
- `shelfstack-governing-docs.mdc` — when editing ADRs, domains, workflows

## Git and pull requests

Use a lightweight trunk-based model on `main`. See [git-workflow.md](git-workflow.md).

Summary:

- roadmap phases plan work; issues track units of work; short-lived branches implement; PRs integrate;
- no permanent `develop` or `phase-*` branches;
- prefer squash merges to `main` with CI green;
- put docs with the code they govern (or small `docs/` PRs for open decisions).

## Delivery approach

ShelfStack uses a **POS-forward** delivery order:

1. organization and authorization;
2. configuration and catalog;
3. thin quantity inventory (adjustments, not purchasing);
4. POS through atomic completion;
5. purchasing, receiving, and product requests;
6. corrections and stored value;
6.5. cashier workspace (interaction gate over existing POS services);
7. reporting and reconciliation.

Full purchasing does not block the first real, inventory-aware completed sale.

## Related documentation

- [System Overview](../architecture/system-overview.md)
- [Domain Map](../architecture/domain-map.md)
- [Invariants](../architecture/invariants.md)
- [ADRs](../adr/README.md)
- [Domain Specifications](../domains/README.md)
- [Permission catalog](../domains/authorization-permissions.md)
- [Identifier guide](../reference/identifiers.md)
- [Workflows](../workflows/README.md)
- [Proforma Schema Exports](../exports/schema/README.md)
