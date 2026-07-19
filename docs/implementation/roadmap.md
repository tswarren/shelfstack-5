# ShelfStack Implementation Roadmap

**Status:** Active  
**Approach:** POS-forward delivery  
**Current phase:** [current-phase.md](current-phase.md)  
**Locks:** [architectural-locks.md](architectural-locks.md)  
**Open decisions:** [open-decisions.md](open-decisions.md)  
**Design (cross-cutting):** [../design/README.md](../design/README.md)  
**Git workflow:** [git-workflow.md](git-workflow.md)


## Central decision

Full purchasing and product-request workflows must **not** block a real, inventory-aware POS completion path.

The first vertical slice is:

```text
opening inventory adjustment
→ quantity reservation
→ atomic POS completion
→ inventory movement + cost snapshot + receipt number
```

Purchase orders do not create on-hand stock, so they are not a prerequisite for that slice.

## Delivery sequence

```mermaid
flowchart TD
  P0[Phase0_ScaffoldAndLocks]
  P1[Phase1_OrgAuth]
  P2[Phase2_ConfigCatalog]
  P3[Phase3_QtyInventoryBootstrap]
  P4a[Phase4a_EditablePOS]
  P4b[Phase4b_PriceTaxApprovals]
  P4c[Phase4c_TenderCompletion]
  P4d[Phase4d_IndividualUnits]
  P4e[Phase4e_LinkedReturns]
  P5f[Phase5_FoundationalPurchasing]
  P5u[Phase5_UnitDependentFulfilment]
  P6[Phase6_CorrectionsStoredValue]
  P7[Phase7_Reporting]
  P8[Phase8_Deferred]

  P0 --> P1 --> P2 --> P3 --> P4a --> P4b --> P4c
  P4c --> P4d
  P4c --> P4e
  P4c --> P5f
  P4d --> P5u
  P5f --> P5u
  P5u --> P6 --> P7 --> P8
  P4e --> P6
```

| Phase | Name | Status | Document |
| --- | --- | --- | --- |
| 0 | Scaffold and architectural locks | Complete | [phases/phase-00-scaffold-and-locks.md](phases/phase-00-scaffold-and-locks.md) |
| 1 | Organization and authorization | Complete | [phases/phase-01-organization-and-authorization.md](phases/phase-01-organization-and-authorization.md) |
| 2 | Configuration and catalog | Complete | [phases/phase-02-configuration-and-catalog.md](phases/phase-02-configuration-and-catalog.md) |
| 3 | Quantity inventory bootstrap | Complete | [phases/phase-03-quantity-inventory-bootstrap.md](phases/phase-03-quantity-inventory-bootstrap.md) |
| 4 | Point of sale (4a–4e) | Implemented on `phase/p4-point-of-sale` (not merged to `main` pending manual testing) | [phases/phase-04-point-of-sale.md](phases/phase-04-point-of-sale.md) |
| 5 | Supply and demand | Not started — **Option B unlock:** foundational purchasing after 4c; unit-dependent fulfilment after 4d (both gates satisfied on the Phase 4 branch) | [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md) |
| 6 | Corrections and stored value | Not started | [phases/phase-06-corrections-and-stored-value.md](phases/phase-06-corrections-and-stored-value.md) |
| 7 | Reporting and reconciliation | Not started | [phases/phase-07-reporting-and-reconciliation.md](phases/phase-07-reporting-and-reconciliation.md) |
| 8 | Deferred capabilities | Deferred | [deferred-capabilities.md](deferred-capabilities.md) |

## Mapping to system-overview §1.8

Conceptual phases in the System Overview describe domain dependencies. Delivery phases reorder work for an earlier completed-sale milestone.

| System Overview | Delivery phase | Notes |
| --- | --- | --- |
| Phase 1 Org / auth | Delivery Phase 1 | Same |
| Phase 2 Definitions / catalog | Delivery Phase 2 | Same; no display categories |
| Phase 3 Requests / purchasing | Delivery Phase 5 | After first POS completion |
| Phase 4 Receiving / inventory | Delivery Phase 3 (thin bootstrap) + Phase 5 (full receiving) | Bootstrap uses adjustments only |
| Phases 5–7 POS | Delivery Phase 4a–4e | Pulled forward |
| Phase 8 Corrections / stored value | Delivery Phase 6 | Same |
| Phase 9 Reporting | Delivery Phase 7 | Same |
| Phase 10 Later extensions | Delivery Phase 8 / deferred | Same |

## Cross-cutting engineering rules

- Prefer application services for multi-record workflows; models enforce local invariants.
- Store monetary amounts in integer cents.
- Deactivate master records rather than deleting them when history may reference them.
- Add database constraints for critical uniqueness and concurrency.
- Only inventory movements posted through ledger services change `on_hand`.
- Do not invent deferred workflows (see [deferred-capabilities.md](deferred-capabilities.md)).
- Tests scale with risk: concurrency and idempotency required for inventory, money, and completion.
- UI/UX is a cross-cutting responsibility ([../design/](../design/README.md)): mockups are a north star, not business-logic contracts. The **UX Baseline Gate** (Phase 4f) must complete before Phase 5 so new screens inherit shared shell, form, table, and page patterns.

## Near-term cadence

Completed: Phases 0–4 (Phase 4a–4e Point of Sale on `main`).

**Active:** Phase 4f — UX Baseline Gate on `phase/ux-baseline`. See [phases/phase-04f-ux-baseline.md](phases/phase-04f-ux-baseline.md).

**Phase 5 unlock (Option B — accepted; gated by UX baseline):**

| Phase 5 work | Gate | Status |
| --- | --- | --- |
| Foundational purchasing (vendors, POs, quantity receiving, quantity requests/allocations) | After **4c** + **UX Baseline Gate** | Domain gate satisfied; start after 4f merges |
| Unit-dependent fulfilment (unit-backed receipt lines, exact-copy request fulfilment) | After **4d** + **UX Baseline Gate** | Domain gate satisfied; start after 4f merges |
| Return/refund-oriented fulfilment paths | **4e** recommended + **UX Baseline Gate** | Domain gate satisfied; start after 4f merges |

1. Complete Phase 4f UX Baseline Gate on `phase/ux-baseline` (four milestone PRs + manual walkthrough) before merge to `main`
2. Begin Phase 5 foundational purchasing / receiving / requests using Baseline page patterns (`P4c → P5f`; `P4d → P5u`)
3. Phases 6–7 as separate epics



## Schema and seed inputs

- Reconciled proforma: [../exports/schema/](../exports/schema/)
- Classification seed CSVs: [../exports/departments.csv](../exports/departments.csv), [../exports/tax_categories.csv](../exports/tax_categories.csv), [../exports/merchandise_classes.csv](../exports/merchandise_classes.csv)
- Pre-scaffolding reconciliation note: [schema-reconciliation-display-categories-and-demand-allocation.md](schema-reconciliation-display-categories-and-demand-allocation.md)

Migrations and `db/schema.rb` become implemented truth. Conflicts with ADRs or Domain Specifications must be resolved explicitly.
