# ShelfStack Implementation Documentation

**Status:** Governing delivery documentation  
**Purpose:** Track how ShelfStack is built in the Rails repository, in what order, and under which architectural locks

## How to use these documents

| Document | Role |
| --- | --- |
| [roadmap.md](roadmap.md) | Master sequence, status, and mapping to system-overview phases |
| [current-phase.md](current-phase.md) | What is in progress right now |
| [architectural-locks.md](architectural-locks.md) | Settled delivery decisions that must not be re-litigated mid-phase |
| [deferred-capabilities.md](deferred-capabilities.md) | Explicitly out of scope until designed |
| [phases/](phases/) | Per-phase goals, tables, services, exit criteria, and out-of-scope |
| [schema-reconciliation-display-categories-and-demand-allocation.md](schema-reconciliation-display-categories-and-demand-allocation.md) | Pre-scaffolding schema decisions (merchandise classes, requests, allocations) |

## Authority

Implementation plans sit below ADRs and Domain Specifications:

1. accepted ADR;
2. Domain Specification;
3. schema documentation / reconciled proforma;
4. workflow documentation;
5. **these implementation documents**;
6. archived material.

When delivery order differs from the conceptual sequence in [system-overview §1.8](../architecture/system-overview.md), this roadmap is authoritative for **build order**. It does not change domain ownership or invariants.

## Delivery approach

ShelfStack uses a **POS-forward** delivery order:

1. organization and authorization;
2. configuration and catalog;
3. thin quantity inventory (adjustments, not purchasing);
4. POS through atomic completion;
5. purchasing, receiving, and product requests;
6. corrections and stored value;
7. reporting and reconciliation.

Full purchasing does not block the first real, inventory-aware completed sale.

## Related documentation

- [System Overview](../architecture/system-overview.md)
- [Domain Map](../architecture/domain-map.md)
- [Invariants](../architecture/invariants.md)
- [ADRs](../adr/README.md)
- [Domain Specifications](../domains/README.md)
- [Proforma Schema Exports](../exports/schema/README.md)
